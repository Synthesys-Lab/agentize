"""Kernel functions for the modular lol impl workflow."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any, Callable

from agentize.shell import run_shell_function
from agentize.workflow.api import gh as gh_utils
from agentize.workflow.api import prompt as prompt_utils
from agentize.workflow.api.session import PipelineError
from agentize.workflow.impl.state import (
    EVENT_FATAL,
    EVENT_IMPL_DONE,
    EVENT_IMPL_NOT_DONE,
    EVENT_PARSE_FAIL,
    EVENT_PR_FAIL_FIXABLE,
    EVENT_PR_FAIL_NEED_REBASE,
    EVENT_PR_PASS,
    EVENT_REBASE_CONFLICT,
    EVENT_REBASE_OK,
    EVENT_REVIEW_FAIL,
    EVENT_REVIEW_PASS,
    EVENT_SIMP_FAIL,
    EVENT_SIMP_PASS,
    STAGE_IMPL,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_REVIEW,
    STAGE_SIMP,
    Event,
    Stage,
    StageResult,
    WorkflowContext,
)

if TYPE_CHECKING:
    from agentize.workflow.api import Session
    from agentize.workflow.impl.checkpoint import ImplState


def impl_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM stage kernel for impl stage.

    Calls impl_kernel(), runs parse gate on completion, tracks
    parse_fail_streak, and emits the appropriate event.
    """
    from datetime import datetime

    state: ImplState = context.data["impl_state"]
    session = context.data["session"]
    template_path = context.data["template_path"]
    impl_provider = context.data["impl_provider"]
    impl_model = context.data["impl_model"]
    yolo = context.data.get("yolo", False)
    max_iterations = context.data.get("max_iterations", 10)
    enable_review = context.data.get("enable_review", False)

    if state.iteration > max_iterations:
        return StageResult(
            event=EVENT_FATAL,
            reason=f"Max iteration limit ({max_iterations}) reached",
        )

    score, feedback, result = impl_kernel(
        state,
        session,
        template_path=template_path,
        provider=impl_provider,
        model=impl_model,
        yolo=yolo,
        ci_failure=context.data.get("retry_context"),
    )
    context.data["retry_context"] = None

    state.last_feedback = feedback
    state.last_score = score
    state.history.append({
        "stage": "impl",
        "iteration": state.iteration,
        "timestamp": datetime.now().isoformat(),
        "result": "success" if result.get("completion_found") else "incomplete",
        "score": score,
    })

    if result.get("completion_found"):
        parse_passed, parse_feedback, parse_report = run_parse_gate(
            state,
            files_changed=bool(result.get("files_changed")),
        )
        print(parse_feedback)
        print(f"Parse report: {parse_report}")
        state.history.append({
            "stage": "parse",
            "iteration": state.iteration,
            "timestamp": datetime.now().isoformat(),
            "result": "pass" if parse_passed else "fail",
            "score": None,
            "artifact": str(parse_report),
        })

        if not parse_passed:
            context.data["parse_fail_streak"] = context.data.get("parse_fail_streak", 0) + 1
            if context.data["parse_fail_streak"] >= 3:
                return StageResult(
                    event=EVENT_FATAL,
                    reason="Reached parse gate retry limit (3 consecutive parse failures).",
                )
            state.last_feedback = parse_feedback
            parse_report_text = parse_report.read_text() if parse_report.exists() else ""
            context.data["retry_context"] = (
                "Parse gate failure context:\n"
                f"{parse_report_text}"
            ).strip()
            state.iteration += 1
            return StageResult(event=EVENT_PARSE_FAIL, reason=parse_feedback)

        context.data["parse_fail_streak"] = 0
        if enable_review:
            context.data["review_attempts"] = 0
            context.data["review_fail_streak"] = 0
            context.data["last_review_score"] = None
        return StageResult(event=EVENT_IMPL_DONE, reason=parse_feedback)

    # No completion found
    state.iteration += 1
    return StageResult(event=EVENT_IMPL_NOT_DONE, reason="completion marker missing")


def review_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM stage kernel for review stage.

    Handles enable_review=False shortcut, calls review_kernel(),
    tracks convergence via review_fail_streak, and emits the appropriate event.
    """
    from datetime import datetime

    state: ImplState = context.data["impl_state"]
    enable_review = context.data.get("enable_review", False)
    max_reviews = context.data.get("max_reviews", 8)

    if not enable_review:
        return StageResult(event=EVENT_REVIEW_PASS, reason="review disabled")

    context.data["review_attempts"] = context.data.get("review_attempts", 0) + 1
    if context.data["review_attempts"] > max_reviews:
        return StageResult(
            event=EVENT_REVIEW_PASS,
            reason=f"Max review attempts ({max_reviews}) reached, proceeding to PR",
        )

    session = context.data["session"]
    review_provider = context.data["review_provider"]
    review_model_name = context.data["review_model"]

    passed, feedback, score = review_kernel(
        state,
        session,
        provider=review_provider,
        model=review_model_name,
    )

    tmp_dir = state.worktree / ".tmp"
    review_report = tmp_dir / f"review-iter-{state.iteration}.json"
    if review_report.exists():
        print(f"Review report: {review_report}")

    state.last_feedback = feedback
    state.last_score = score
    state.history.append({
        "stage": "review",
        "iteration": state.iteration,
        "timestamp": datetime.now().isoformat(),
        "result": "pass" if passed else "retry",
        "score": score,
    })

    if passed:
        context.data["review_fail_streak"] = 0
        context.data["last_review_score"] = score
        return StageResult(event=EVENT_REVIEW_PASS, reason=f"score {score}")

    # Track convergence
    last_review_score = context.data.get("last_review_score")
    if last_review_score is None or score > last_review_score:
        context.data["review_fail_streak"] = 1
    else:
        context.data["review_fail_streak"] = context.data.get("review_fail_streak", 0) + 1
    context.data["last_review_score"] = score

    if context.data.get("review_fail_streak", 0) >= 4:
        return StageResult(
            event=EVENT_FATAL,
            reason="Review scores showed no improvement for 4 consecutive failures.",
        )

    review_report_text = review_report.read_text() if review_report.exists() else ""
    context.data["retry_context"] = (
        "Review failure context:\n"
        f"{feedback}\n\n"
        f"Structured review report:\n{review_report_text}"
    ).strip()
    state.iteration += 1
    return StageResult(event=EVENT_REVIEW_FAIL, reason=f"score {score}")


def pr_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM stage kernel for PR stage.

    Calls pr_kernel(), passes through event, tracks pr_attempts (limit 6).
    """
    from datetime import datetime

    state: ImplState = context.data["impl_state"]
    push_remote = context.data.get("push_remote")
    base_branch = context.data.get("base_branch")

    context.data["pr_attempts"] = context.data.get("pr_attempts", 0) + 1
    if context.data["pr_attempts"] > 6:
        return StageResult(
            event=EVENT_FATAL,
            reason="Reached PR retry limit (6 attempts).",
        )

    event, message, pr_number, pr_url, pr_report = pr_kernel(
        state,
        None,
        push_remote=push_remote,
        base_branch=base_branch,
    )

    print(f"PR report: {pr_report}")

    state.history.append({
        "stage": "pr",
        "iteration": state.iteration,
        "timestamp": datetime.now().isoformat(),
        "result": event,
        "score": None,
        "artifact": str(pr_report),
    })

    state.pr_number = pr_number
    state.pr_url = pr_url

    if event == EVENT_PR_FAIL_FIXABLE:
        pr_report_text = pr_report.read_text() if pr_report.exists() else ""
        context.data["retry_context"] = (
            "PR stage failure context:\n"
            f"{message}\n\n"
            f"Structured PR report:\n{pr_report_text}"
        ).strip()
        state.iteration += 1

    return StageResult(event=event, reason=message)


def rebase_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM stage kernel for rebase stage.

    Calls rebase_kernel(), passes through event, tracks rebase_attempts (limit 3).
    """
    from datetime import datetime

    state: ImplState = context.data["impl_state"]
    push_remote = context.data.get("push_remote")
    base_branch = context.data.get("base_branch")

    context.data["rebase_attempts"] = context.data.get("rebase_attempts", 0) + 1
    if context.data["rebase_attempts"] > 3:
        return StageResult(
            event=EVENT_FATAL,
            reason="Reached rebase retry limit (3 attempts).",
        )

    event, message, rebase_report = rebase_kernel(
        state,
        push_remote=push_remote,
        base_branch=base_branch,
    )
    print(f"Rebase report: {rebase_report}")

    state.history.append({
        "stage": "rebase",
        "iteration": state.iteration,
        "timestamp": datetime.now().isoformat(),
        "result": event,
        "score": None,
        "artifact": str(rebase_report),
    })

    if event == EVENT_REBASE_OK:
        state.iteration += 1

    return StageResult(event=event, reason=message)


def simp_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM stage kernel for simplification stage.

    Handles enable_simp=False shortcut, calls simp_kernel(),
    tracks simp_attempts (limit max_simps), and emits the appropriate event.
    """
    from datetime import datetime

    state: ImplState = context.data["impl_state"]
    enable_simp = context.data.get("enable_simp", False)
    max_simps = context.data.get("max_simps", 3)

    if not enable_simp:
        return StageResult(event=EVENT_SIMP_PASS, reason="simp disabled")

    context.data["simp_attempts"] = context.data.get("simp_attempts", 0) + 1
    if context.data["simp_attempts"] > max_simps:
        return StageResult(
            event=EVENT_SIMP_PASS,
            reason=f"Max simp attempts ({max_simps}) reached, proceeding to PR",
        )

    session = context.data["session"]
    impl_provider = context.data["impl_provider"]
    impl_model = context.data["impl_model"]

    passed, feedback = simp_kernel(
        state,
        session,
        provider=impl_provider,
        model=impl_model,
    )

    state.history.append({
        "stage": "simp",
        "iteration": state.iteration,
        "timestamp": datetime.now().isoformat(),
        "result": "pass" if passed else "fail",
        "score": None,
    })

    if passed:
        return StageResult(event=EVENT_SIMP_PASS, reason=feedback)

    context.data["retry_context"] = (
        "Simplification feedback:\n"
        f"{feedback}"
    ).strip()
    state.iteration += 1
    return StageResult(event=EVENT_SIMP_FAIL, reason=feedback)


KERNELS: dict[Stage, Callable[[WorkflowContext], StageResult]] = {
    STAGE_IMPL: impl_stage_kernel,
    STAGE_REVIEW: review_stage_kernel,
    STAGE_SIMP: simp_stage_kernel,
    STAGE_PR: pr_stage_kernel,
    STAGE_REBASE: rebase_stage_kernel,
}


REVIEW_SCORE_KEYS: tuple[str, ...] = (
    "faithful",
    "style",
    "docs",
    "corner_cases",
)

REVIEW_SCORE_THRESHOLDS: dict[str, int] = {
    "faithful": 90,
    "style": 85,
    "docs": 85,
    "corner_cases": 85,
}


def _clamp_score(value: int) -> int:
    return min(100, max(0, value))


def _coerce_score(value: object, *, fallback: int) -> int:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, (int, float)):
        return _clamp_score(int(round(value)))
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return fallback
        try:
            return _clamp_score(int(round(float(stripped))))
        except ValueError:
            return fallback
    return fallback


def _json_object_candidates(output: str) -> list[str]:
    candidates: list[str] = []
    stripped = output.strip()
    if stripped:
        candidates.append(stripped)

    fenced = re.findall(r"```(?:json)?\s*(\{.*?\})\s*```", output, flags=re.DOTALL)
    candidates.extend(block.strip() for block in fenced if block.strip())

    start = output.find("{")
    end = output.rfind("}")
    if start >= 0 and end > start:
        candidates.append(output[start:end + 1].strip())

    deduped: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        deduped.append(candidate)
    return deduped


def _extract_review_json(output: str) -> dict[str, Any] | None:
    for candidate in _json_object_candidates(output):
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            return parsed
    return None


def _normalize_list(value: object) -> list[str]:
    if isinstance(value, list):
        normalized = [str(item).strip() for item in value if str(item).strip()]
        return normalized
    if isinstance(value, str):
        lines = [line.strip().lstrip("- ").strip() for line in value.splitlines()]
        return [line for line in lines if line]
    return []


def _extract_named_list(output: str, section_name: str) -> list[str]:
    pattern = re.compile(
        rf"{section_name}\s*:\s*(.*?)(?:\n\s*[A-Za-z_][A-Za-z0-9_ ]*\s*:|\Z)",
        flags=re.IGNORECASE | re.DOTALL,
    )
    match = pattern.search(output)
    if not match:
        return []
    return _normalize_list(match.group(1))


def _coerce_review_scores(raw: object, *, fallback_score: int) -> dict[str, int]:
    if isinstance(raw, dict):
        source = raw
    else:
        source = {}

    return {
        key: _coerce_score(source.get(key), fallback=fallback_score)
        for key in REVIEW_SCORE_KEYS
    }


def _overall_review_score(
    review_json: dict[str, Any] | None,
    *,
    fallback_score: int,
    scores: dict[str, int],
) -> int:
    if review_json:
        for key in ("overall_score", "overall", "score"):
            if key in review_json:
                return _coerce_score(review_json[key], fallback=fallback_score)

    if fallback_score != 50:
        return fallback_score

    if not scores:
        return 0

    return int(round(sum(scores.values()) / len(scores)))


def _score_threshold_failures(scores: dict[str, int], thresholds: dict[str, int]) -> list[str]:
    failures: list[str] = []
    for key in REVIEW_SCORE_KEYS:
        threshold = thresholds.get(key, 0)
        score = scores.get(key, 0)
        if score < threshold:
            failures.append(f"{key}={score}<{threshold}")
    return failures


def _parse_quality_score(output: str) -> int:
    """Extract quality score from kernel output text.

    Extracts a 0-100 score from output containing patterns like:
    - "Score: 85/100"
    - "Quality: 85"
    - "Rating: 8.5/10"

    Args:
        output: The output text to parse.

    Returns:
        Parsed score 0-100, or 50 (neutral) if no score found.
    """
    # Try "Score: XX/100" pattern (accepts negative numbers too, clamped below)
    match = re.search(r"[Ss]core[:\s]+(-?\d+)/100", output)
    if match:
        return min(100, max(0, int(match.group(1))))

    # Try "Quality: XX" pattern
    match = re.search(r"[Qq]uality[:\s]+(-?\d+)(?:/100)?", output)
    if match:
        return min(100, max(0, int(match.group(1))))

    # Try "Rating: X.X/10" pattern
    match = re.search(r"[Rr]ating[:\s]+(-?\d+\.?\d*)/10", output)
    if match:
        return min(100, max(0, int(float(match.group(1)) * 10)))

    return 50  # Neutral default


def _parse_completion_marker(finalize_file: Path, issue_no: int) -> bool:
    """Check if finalize file contains completion marker.

    Args:
        finalize_file: Path to the finalize file.
        issue_no: The issue number to check for.

    Returns:
        True if the file contains "Issue {N} resolved".
    """
    if not finalize_file.exists():
        return False
    content = finalize_file.read_text()
    return f"Issue {issue_no} resolved" in content


def _read_optional(path: Path) -> str | None:
    """Read file content if it exists and is non-empty.

    Args:
        path: Path to the file.

    Returns:
        File content or None if file doesn't exist or is empty.
    """
    if path.exists() and path.is_file():
        content = path.read_text()
        if content.strip():
            return content
    return None


def _shell_cmd(parts: list[str | Path]) -> str:
    """Build a shell command from parts.

    Args:
        parts: Command parts to quote and join.

    Returns:
        Shell-quoted command string.
    """
    import shlex

    return " ".join(shlex.quote(str(part)) for part in parts)


def _latest_commit_python_files(worktree_path: Path) -> list[str]:
    """Collect Python files changed in the latest commit.

    Args:
        worktree_path: Path to the git worktree.

    Returns:
        Sorted list of repository-relative Python file paths that exist.

    Raises:
        ImplError: If commit diff cannot be determined.
    """
    from agentize.workflow.impl.impl import ImplError

    diff_cmd = _shell_cmd(["git", "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"])
    result = run_shell_function(diff_cmd, capture_output=True, cwd=worktree_path)
    if result.returncode != 0:
        raise ImplError("Error: Failed to inspect latest commit for parse gate")

    python_files: list[str] = []
    for raw_path in result.stdout.splitlines():
        relative_path = raw_path.strip()
        if not relative_path.endswith(".py"):
            continue

        absolute_path = worktree_path / relative_path
        if absolute_path.exists() and absolute_path.is_file():
            python_files.append(relative_path)

    return sorted(dict.fromkeys(python_files))


def _parse_failed_python_files(py_compile_output: str) -> list[str]:
    """Extract failed Python file paths from py_compile output."""
    matches = re.findall(r'File "([^"]+\.py)"', py_compile_output)
    return sorted(dict.fromkeys(matches))


def run_parse_gate(
    state: ImplState,
    *,
    files_changed: bool,
) -> tuple[bool, str, Path]:
    """Run deterministic Python parse gate for the current iteration.

    Args:
        state: Current workflow state.
        files_changed: Whether current iteration produced a commit.

    Returns:
        Tuple of (passed, feedback, report_path).
    """
    tmp_dir = state.worktree / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    report_path = tmp_dir / f"parse-iter-{state.iteration}.json"

    if not files_changed:
        report = {
            "pass": True,
            "failed_files": [],
            "traceback": "",
            "suggestions": ["No Python files changed in this iteration."],
        }
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        return True, "Parse gate skipped: no changed Python files.", report_path

    python_files = _latest_commit_python_files(state.worktree)
    if not python_files:
        report = {
            "pass": True,
            "failed_files": [],
            "traceback": "",
            "suggestions": ["No Python files changed in this iteration."],
        }
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        return True, "Parse gate passed: no changed Python files.", report_path

    parse_cmd = _shell_cmd(["python", "-m", "py_compile", *python_files])
    parse_result = run_shell_function(parse_cmd, capture_output=True, cwd=state.worktree)

    traceback_text = parse_result.stderr.strip() or parse_result.stdout.strip()
    if parse_result.returncode == 0:
        report = {
            "pass": True,
            "failed_files": [],
            "traceback": "",
            "suggestions": [],
        }
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        return True, f"Parse gate passed for {len(python_files)} file(s).", report_path

    failed_files = _parse_failed_python_files(traceback_text) or python_files
    report = {
        "pass": False,
        "failed_files": failed_files,
        "traceback": traceback_text,
        "suggestions": [
            "Fix syntax errors in failed files before rerunning implementation.",
            "Re-run python -m py_compile on changed Python files locally.",
        ],
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n")

    return (
        False,
        f"Parse gate failed for {len(failed_files)} file(s). See {report_path}.",
        report_path,
    )


def _stage_and_commit(
    worktree_path: Path,
    commit_report_file: Path,
    iteration: int,
) -> bool:
    """Stage and commit changes.

    Args:
        worktree_path: Path to the git worktree.
        commit_report_file: Path to the commit message file.
        iteration: Current iteration number.

    Returns:
        True if changes were committed, False if no changes to commit.

    Raises:
        ImplError: If staging or commit fails.
    """
    from agentize.workflow.impl.impl import ImplError

    add_result = run_shell_function("git add -A", cwd=worktree_path)
    if add_result.returncode != 0:
        raise ImplError(f"Error: Failed to stage changes for iteration {iteration}")

    diff_result = run_shell_function(
        "git diff --cached --quiet",
        cwd=worktree_path,
    )
    if diff_result.returncode == 0:
        print(f"No changes to commit for iteration {iteration}")
        return False
    if diff_result.returncode not in (0, 1):
        raise ImplError(
            f"Error: Failed to check staged changes for iteration {iteration}"
        )

    commit_cmd = _shell_cmd([
        "git",
        "commit",
        "-F",
        str(commit_report_file),
    ])
    commit_result = run_shell_function(commit_cmd, cwd=worktree_path)
    if commit_result.returncode != 0:
        raise ImplError(f"Error: Failed to commit iteration {iteration}")

    return True


def _iteration_section(iteration: int | None) -> str:
    """Generate iteration section text.

    Args:
        iteration: Current iteration number or None.

    Returns:
        Iteration section string.
    """
    if iteration is None:
        return ""
    return (
        f"Current iteration: {iteration}\n"
        f"Create .tmp/commit-report-iter-{iteration}.txt for this iteration.\n"
    )


def _section(title: str, content: str | None) -> str:
    """Generate a section with title and content.

    Args:
        title: Section title.
        content: Section content or None.

    Returns:
        Formatted section or empty string if no content.
    """
    if not content:
        return ""
    return f"\n\n---\n{title}\n{content.rstrip()}\n".rstrip() + "\n"


def _render_impl_prompt(
    template_path: Path,
    state: ImplState,
    output_file: Path,
    finalize_file: Path,
    iteration: int,
    previous_output: str | None = None,
    previous_commit_report: str | None = None,
    ci_failure: str | None = None,
) -> str:
    """Render the implementation prompt from template.

    Args:
        template_path: Path to the prompt template.
        state: Current workflow state.
        output_file: Path to the output file.
        finalize_file: Path to the finalize file.
        iteration: Current iteration number.
        previous_output: Previous iteration output or None.
        previous_commit_report: Previous commit report or None.
        ci_failure: CI failure context or None.

    Returns:
        Rendered prompt text.
    """
    issue_file = state.worktree / ".tmp" / f"issue-{state.issue_no}.md"

    replacements = {
        "issue_no": str(state.issue_no),
        "issue_file": str(issue_file),
        "finalize_file": str(finalize_file),
        "iteration_section": _iteration_section(iteration),
        "previous_output_section": _section(
            "Output from last iteration:",
            previous_output,
        ),
        "previous_commit_report_section": _section(
            "Previous iteration summary (commit report):",
            previous_commit_report,
        ),
        "ci_failure_section": _section(
            "CI failure context:",
            ci_failure,
        ),
    }

    return prompt_utils.render(template_path, replacements, output_file)


def impl_kernel(
    state: ImplState,
    session: Session,
    *,
    template_path: Path,
    provider: str,
    model: str,
    yolo: bool = False,
    ci_failure: str | None = None,
) -> tuple[int, str, dict]:
    """Execute implementation generation for the current iteration.

    Args:
        state: Current workflow state.
        session: Session for running prompts.
        template_path: Path to the prompt template file.
        provider: Model provider.
        model: Model name.
        yolo: Pass-through flag for ACW autonomy.
        ci_failure: CI failure context for retry iterations.

    Returns:
        Tuple of (score, feedback, result_dict) where result_dict contains:
        - files_changed: bool indicating if changes were committed
        - completion_found: bool indicating if completion marker was found
    """
    from agentize.workflow.impl.impl import ImplError

    tmp_dir = state.worktree / ".tmp"
    output_file = tmp_dir / "impl-output.txt"
    finalize_file = tmp_dir / "finalize.txt"
    input_file = tmp_dir / f"impl-input-{state.iteration}.txt"

    print(f"Iteration {state.iteration}...")

    # Read previous outputs
    previous_output = _read_optional(output_file)
    previous_commit_report = None
    if state.iteration > 1:
        previous_commit_report = _read_optional(
            tmp_dir / f"commit-report-iter-{state.iteration - 1}.txt"
        )

    # Render prompt
    prompt_text = _render_impl_prompt(
        template_path,
        state,
        output_file,
        finalize_file,
        state.iteration,
        previous_output=previous_output,
        previous_commit_report=previous_commit_report,
        ci_failure=ci_failure,
    )

    # Run the prompt
    extra_flags = ["--yolo"] if yolo else None
    try:
        result = session.run_prompt(
            f"impl-iter-{state.iteration}",
            prompt_text,
            (provider, model),
            extra_flags=extra_flags,
            input_path=input_file,
            output_path=output_file,
        )
    except PipelineError as exc:
        print(
            f"Warning: acw failed on iteration {state.iteration} ({exc})",
            file=sys.stderr,
        )
        # Return partial result
        return 0, f"Pipeline error: {exc}", {
            "files_changed": False,
            "completion_found": False,
        }

    # Check for completion marker
    completion_found = _parse_completion_marker(finalize_file, state.issue_no)

    # Parse quality score from output
    output_text = result.text() if result.output_path.exists() else ""
    score = _parse_quality_score(output_text)

    # Look for commit report
    commit_report_file = tmp_dir / f"commit-report-iter-{state.iteration}.txt"
    commit_report = _read_optional(commit_report_file)

    files_changed = False
    if commit_report:
        files_changed = _stage_and_commit(
            state.worktree,
            commit_report_file,
            state.iteration,
        )
    elif completion_found:
        raise ImplError(
            f"Error: Missing commit report for iteration {state.iteration}\n"
            f"Expected: {commit_report_file}"
        )
    else:
        print(
            f"Warning: Missing commit report for iteration {state.iteration}; "
            "skipping commit.",
            file=sys.stderr,
        )

    feedback = f"Implementation iteration {state.iteration} completed"
    if completion_found:
        feedback += " (completion marker found)"

    return score, feedback, {
        "files_changed": files_changed,
        "completion_found": completion_found,
    }


def review_kernel(
    state: ImplState,
    session: Session,
    *,
    provider: str,
    model: str,
) -> tuple[bool, str, int]:
    """Review implementation quality and provide feedback.

    Args:
        state: Current workflow state including last implementation.
        session: Session for running prompts.
        provider: Model provider.
        model: Model name.

    Returns:
        Tuple of (passed, feedback, score) where:
        - passed: True if implementation passes quality threshold
        - feedback: Detailed feedback for re-implementation if failed
        - score: Quality score from 0-100
    """
    tmp_dir = state.worktree / ".tmp"
    output_file = tmp_dir / "impl-output.txt"
    issue_file = tmp_dir / f"issue-{state.issue_no}.md"
    review_report_file = tmp_dir / f"review-iter-{state.iteration}.json"

    if not output_file.exists():
        return False, "No implementation output found to review", 0

    impl_output = output_file.read_text()
    issue_content = issue_file.read_text() if issue_file.exists() else ""

    review_prompt = f"""Review the following implementation against issue requirements.

Issue Requirements:
{issue_content}

Implementation:
{impl_output[:8000]}

Output JSON only with this schema:
{{
  "scores": {{
    "faithful": <0-100 int>,
    "style": <0-100 int>,
    "docs": <0-100 int>,
    "corner_cases": <0-100 int>
  }},
  "overall_score": <0-100 int>,
  "findings": ["..."],
  "suggestions": ["..."]
}}

Scoring constraints:
- faithful >= 90
- style >= 85
- docs >= 85
- corner_cases >= 85

Be strict and objective. No markdown wrapper.
"""

    input_file = tmp_dir / f"review-input-{state.iteration}.txt"
    review_output_file = tmp_dir / f"review-output-{state.iteration}.txt"

    try:
        result = session.run_prompt(
            f"review-{state.iteration}",
            review_prompt,
            (provider, model),
            input_path=input_file,
            output_path=review_output_file,
        )
    except PipelineError as exc:
        print(f"Warning: Review failed ({exc})", file=sys.stderr)
        report = {
            "scores": {key: 0 for key in REVIEW_SCORE_KEYS},
            "pass": False,
            "findings": [f"Review pipeline error: {exc}"],
            "suggestions": ["Retry review stage and inspect model/runtime connectivity."],
            "raw_output_path": str(review_output_file),
        }
        review_report_file.write_text(json.dumps(report, indent=2) + "\n")
        return False, f"Review pipeline error: {exc}", 0

    review_text = result.text() if result.output_path.exists() else ""
    fallback_score = _parse_quality_score(review_text)
    review_json = _extract_review_json(review_text)
    raw_scores: object = {}
    if review_json:
        raw_scores = review_json.get("scores")
        if not isinstance(raw_scores, dict):
            raw_scores = review_json

    scores = _coerce_review_scores(raw_scores, fallback_score=fallback_score)
    threshold_failures = _score_threshold_failures(scores, REVIEW_SCORE_THRESHOLDS)
    passed = len(threshold_failures) == 0

    findings: list[str] = []
    suggestions: list[str] = []
    if review_json:
        findings = _normalize_list(review_json.get("findings"))
        suggestions = _normalize_list(review_json.get("suggestions"))

    if not findings:
        findings = _extract_named_list(review_text, "Findings")
    if not findings:
        findings = _extract_named_list(review_text, "Feedback")
    if not suggestions:
        suggestions = _extract_named_list(review_text, "Suggestions")

    if not passed and not suggestions:
        suggestions = [
            (
                "Raise review scores to threshold: "
                + ", ".join(threshold_failures)
            )
        ]

    report = {
        "scores": scores,
        "pass": passed,
        "findings": findings,
        "suggestions": suggestions,
        "raw_output_path": str(review_output_file),
    }
    review_report_file.write_text(json.dumps(report, indent=2) + "\n")

    feedback_points = suggestions or findings
    feedback = "\n".join(feedback_points).strip() or "No actionable review feedback provided"
    overall_score = _overall_review_score(
        review_json,
        fallback_score=fallback_score,
        scores=scores,
    )
    return passed, feedback, overall_score


def simp_kernel(
    state: ImplState,
    session: Session,
    *,
    provider: str,
    model: str,
    max_files: int = 3,
) -> tuple[bool, str]:
    """Simplify/refine the implementation.

    Args:
        state: Current workflow state.
        session: Session for running prompts (unused, kept for signature).
        provider: Model provider.
        model: Model name.
        max_files: Maximum files to simplify at once.

    Returns:
        Tuple of (passed, feedback) where:
        - passed: True if simplification succeeded
        - feedback: Summary of simplifications or errors
    """
    from agentize.workflow.simp.simp import SimpError, run_simp_workflow

    backend = f"{provider}:{model}"

    try:
        # Run simp workflow with issue number for context
        run_simp_workflow(
            file_path=None,  # Let simp auto-select files
            backend=backend,
            max_files=max_files,
            issue_number=state.issue_no,
            focus=f"Simplify implementation for issue #{state.issue_no}",
        )
        return True, "Simplification completed successfully"
    except SimpError as exc:
        return False, f"Simplification failed: {exc}"
    except Exception as exc:
        return False, f"Unexpected error during simplification: {exc}"


def _detect_push_remote(worktree_path: Path) -> str:
    """Detect the push remote for the repository.

    Args:
        worktree_path: Path to the git worktree.

    Returns:
        Remote name ("upstream" or "origin").

    Raises:
        ImplError: If no remote found.
    """
    from agentize.workflow.impl.impl import ImplError

    result = run_shell_function("git remote", capture_output=True, cwd=worktree_path)
    if result.returncode != 0:
        raise ImplError("Error: Failed to list git remotes")

    remotes = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if "upstream" in remotes:
        return "upstream"
    if "origin" in remotes:
        return "origin"
    raise ImplError("Error: No remote found (need upstream or origin)")


def _detect_base_branch(worktree_path: Path, remote: str) -> str:
    """Detect the base branch for the repository.

    Args:
        worktree_path: Path to the git worktree.
        remote: Remote name.

    Returns:
        Base branch name ("master" or "main").

    Raises:
        ImplError: If no base branch found.
    """
    from agentize.workflow.impl.impl import ImplError

    for candidate in ("master", "main"):
        check_cmd = _shell_cmd([
            "git",
            "rev-parse",
            "--verify",
            f"refs/remotes/{remote}/{candidate}",
        ])
        result = run_shell_function(check_cmd, capture_output=True, cwd=worktree_path)
        if result.returncode == 0:
            return candidate
    raise ImplError(f"Error: No default branch found (need master or main on {remote})")


def _current_branch(worktree_path: Path) -> str:
    """Get the current branch name.

    Args:
        worktree_path: Path to the git worktree.

    Returns:
        Current branch name.

    Raises:
        ImplError: If branch cannot be determined.
    """
    from agentize.workflow.impl.impl import ImplError

    branch_result = run_shell_function(
        "git branch --show-current",
        capture_output=True,
        cwd=worktree_path,
    )
    branch_name = branch_result.stdout.strip()
    if branch_result.returncode != 0 or not branch_name:
        raise ImplError("Error: Failed to determine current branch")
    return branch_name


def _append_closes_line(finalize_file: Path, issue_no: int) -> None:
    """Append closes line to finalize file if not present.

    Args:
        finalize_file: Path to the finalize file.
        issue_no: The issue number.
    """
    content = finalize_file.read_text()
    if re.search(rf"closes\s+#\s*{issue_no}", content, re.IGNORECASE):
        return
    updated = content.rstrip("\n") + f"\nCloses #{issue_no}\n"
    finalize_file.write_text(updated)


def _write_stage_report(report_path: Path, report: dict[str, Any]) -> None:
    report_path.write_text(json.dumps(report, indent=2) + "\n")


def _needs_rebase(message: str) -> bool:
    lowered = message.lower()
    signatures = (
        "non-fast-forward",
        "fetch first",
        "failed to push some refs",
        "tip of your current branch is behind",
    )
    return any(signature in lowered for signature in signatures)


def pr_kernel(
    state: ImplState,
    session: Session | None,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> tuple[Event, str, str | None, str | None, Path]:
    """Create pull request for the implementation.

    Args:
        state: Current workflow state with finalize content.
        session: Optional session (not used, kept for signature consistency).
        push_remote: Remote to push to (auto-detected if None).
        base_branch: Base branch for PR (auto-detected if None).

    Returns:
        Tuple of (event, message, pr_number, pr_url, report_path) where:
        - event: PR stage event (`pr_pass`/`pr_fail_fixable`/`pr_fail_need_rebase`)
        - message: Summary for logs or retry feedback
        - pr_number: PR number as string if created, None otherwise
        - pr_url: Full PR URL if created, None otherwise
        - report_path: Artifact path for structured PR diagnostics
    """
    from agentize.workflow.impl.impl import ImplError, _validate_pr_title

    _ = session
    tmp_dir = state.worktree / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    finalize_file = tmp_dir / "finalize.txt"
    report_file = tmp_dir / f"pr-iter-{state.iteration}.json"

    # Auto-detect remote and base branch if not provided
    if not push_remote:
        push_remote = _detect_push_remote(state.worktree)
    if not base_branch:
        base_branch = _detect_base_branch(state.worktree, push_remote)

    branch_name = _current_branch(state.worktree)

    # Push branch
    cmd_parts: list[str | Path] = ["git", "push", "-u", push_remote, branch_name]
    push_cmd = _shell_cmd(cmd_parts)
    push_result = run_shell_function(push_cmd, capture_output=True, cwd=state.worktree)
    if push_result.returncode != 0:
        push_output = "\n".join(
            chunk
            for chunk in (push_result.stderr.strip(), push_result.stdout.strip())
            if chunk
        )
        event = EVENT_PR_FAIL_NEED_REBASE if _needs_rebase(push_output) else EVENT_PR_FAIL_FIXABLE
        message = (
            f"Push rejected before PR creation. {'Rebase required.' if event == EVENT_PR_FAIL_NEED_REBASE else 'Manual fix required.'}"
        )
        report = {
            "event": event,
            "pass": False,
            "reason": message,
            "details": push_output,
            "pr_number": None,
            "pr_url": None,
            "branch": branch_name,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return event, message, None, None, report_file

    # Get PR title from finalize file
    pr_title = ""
    if finalize_file.exists():
        pr_title = finalize_file.read_text().splitlines()[0].strip()
    if not pr_title:
        pr_title = f"[feat][#{state.issue_no}] Implementation"

    # Validate format
    try:
        _validate_pr_title(pr_title, state.issue_no)
    except ImplError as exc:
        report = {
            "event": EVENT_PR_FAIL_FIXABLE,
            "pass": False,
            "reason": str(exc),
            "details": "PR title validation failed.",
            "pr_number": None,
            "pr_url": None,
            "branch": branch_name,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return EVENT_PR_FAIL_FIXABLE, str(exc), None, None, report_file

    if not finalize_file.exists():
        finalize_file.write_text(f"{pr_title}\n\n")

    # Append closes line
    _append_closes_line(finalize_file, state.issue_no)
    pr_body = finalize_file.read_text() if finalize_file.exists() else ""

    # Create PR
    try:
        pr_number, pr_url = gh_utils.pr_create(
            pr_title,
            pr_body,
            base=base_branch,
            head=branch_name,
            cwd=state.worktree,
        )
        message = pr_url or f"PR #{pr_number} created"
        report = {
            "event": EVENT_PR_PASS,
            "pass": True,
            "reason": message,
            "details": "",
            "pr_number": pr_number,
            "pr_url": pr_url,
            "branch": branch_name,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return EVENT_PR_PASS, message, pr_number, pr_url, report_file
    except RuntimeError as exc:
        message = f"Failed to create PR: {exc}"
        event = EVENT_PR_FAIL_NEED_REBASE if _needs_rebase(message) else EVENT_PR_FAIL_FIXABLE
        report = {
            "event": event,
            "pass": False,
            "reason": message,
            "details": str(exc),
            "pr_number": None,
            "pr_url": None,
            "branch": branch_name,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return event, message, None, None, report_file


def rebase_kernel(
    state: ImplState,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> tuple[Event, str, Path]:
    """Rebase current branch onto upstream base branch.

    Returns:
        Tuple of (event, message, report_path) where event is `rebase_ok`
        or `rebase_conflict`.
    """
    tmp_dir = state.worktree / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    report_file = tmp_dir / f"rebase-iter-{state.iteration}.json"

    if not push_remote:
        push_remote = _detect_push_remote(state.worktree)
    if not base_branch:
        base_branch = _detect_base_branch(state.worktree, push_remote)

    fetch_cmd = _shell_cmd(["git", "fetch", push_remote])
    fetch_result = run_shell_function(fetch_cmd, capture_output=True, cwd=state.worktree)
    fetch_output = "\n".join(
        chunk
        for chunk in (fetch_result.stderr.strip(), fetch_result.stdout.strip())
        if chunk
    )
    if fetch_result.returncode != 0:
        message = f"Failed to fetch {push_remote}/{base_branch} before rebase."
        report = {
            "event": EVENT_REBASE_CONFLICT,
            "pass": False,
            "reason": message,
            "details": fetch_output,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return EVENT_REBASE_CONFLICT, message, report_file

    rebase_target = f"{push_remote}/{base_branch}"
    rebase_cmd = _shell_cmd(["git", "rebase", rebase_target])
    rebase_result = run_shell_function(rebase_cmd, capture_output=True, cwd=state.worktree)
    rebase_output = "\n".join(
        chunk
        for chunk in (rebase_result.stderr.strip(), rebase_result.stdout.strip())
        if chunk
    )
    if rebase_result.returncode == 0:
        message = f"Rebase completed on {rebase_target}."
        report = {
            "event": EVENT_REBASE_OK,
            "pass": True,
            "reason": message,
            "details": rebase_output,
            "push_remote": push_remote,
            "base_branch": base_branch,
        }
        _write_stage_report(report_file, report)
        return EVENT_REBASE_OK, message, report_file

    run_shell_function(
        _shell_cmd(["git", "rebase", "--abort"]),
        cwd=state.worktree,
    )
    message = f"Rebase conflict detected while rebasing onto {rebase_target}."
    report = {
        "event": EVENT_REBASE_CONFLICT,
        "pass": False,
        "reason": message,
        "details": rebase_output,
        "push_remote": push_remote,
        "base_branch": base_branch,
    }
    _write_stage_report(report_file, report)
    return EVENT_REBASE_CONFLICT, message, report_file
