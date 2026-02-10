"""Kernel functions for the modular lol impl workflow."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Callable

from agentize.shell import run_shell_function
from agentize.workflow.api import gh as gh_utils
from agentize.workflow.api import prompt as prompt_utils
from agentize.workflow.api.session import PipelineError
from agentize.workflow.impl.state import (
    EVENT_FATAL,
    STAGE_IMPL,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_REVIEW,
    Stage,
    StageResult,
    WorkflowContext,
)

if TYPE_CHECKING:
    from agentize.workflow.api import Session
    from agentize.workflow.impl.checkpoint import ImplState


def _unconfigured_kernel(stage: Stage) -> StageResult:
    """Return a fatal stage result for a stage without concrete wiring yet."""
    return StageResult(
        event=EVENT_FATAL,
        reason=f"Kernel not configured for stage: {stage}",
    )


def impl_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM placeholder kernel for impl stage.

    This stage adapter is intentionally minimal in the first FSM scaffold
    iteration and is not yet wired to the production impl kernel.
    """
    return _unconfigured_kernel(STAGE_IMPL)


def review_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM placeholder kernel for review stage."""
    return _unconfigured_kernel(STAGE_REVIEW)


def pr_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM placeholder kernel for PR stage."""
    return _unconfigured_kernel(STAGE_PR)


def rebase_stage_kernel(context: WorkflowContext) -> StageResult:
    """FSM placeholder kernel for rebase stage."""
    return _unconfigured_kernel(STAGE_REBASE)


KERNELS: dict[Stage, Callable[[WorkflowContext], StageResult]] = {
    STAGE_IMPL: impl_stage_kernel,
    STAGE_REVIEW: review_stage_kernel,
    STAGE_PR: pr_stage_kernel,
    STAGE_REBASE: rebase_stage_kernel,
}


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
    threshold: int = 70,
) -> tuple[bool, str, int]:
    """Review implementation quality and provide feedback.

    Args:
        state: Current workflow state including last implementation.
        session: Session for running prompts.
        provider: Model provider.
        model: Model name.
        threshold: Minimum score to pass review (default 70).

    Returns:
        Tuple of (passed, feedback, score) where:
        - passed: True if implementation passes quality threshold
        - feedback: Detailed feedback for re-implementation if failed
        - score: Quality score from 0-100
    """
    tmp_dir = state.worktree / ".tmp"
    output_file = tmp_dir / "impl-output.txt"
    issue_file = tmp_dir / f"issue-{state.issue_no}.md"

    # Read the implementation output
    if not output_file.exists():
        return False, "No implementation output found to review", 0

    impl_output = output_file.read_text()
    issue_content = issue_file.read_text() if issue_file.exists() else ""

    # Build review prompt
    review_prompt = f"""Review the following implementation against the issue requirements.

Issue Requirements:
{issue_content}

Implementation:
{impl_output[:8000]}  # Truncate if too long

Evaluate on these criteria (0-100 scale for each):
1. Code correctness and error handling
2. Test coverage and quality
3. Documentation completeness
4. Adherence to project conventions
5. Issue requirement fulfillment

Provide:
1. Overall Score: X/100
2. Pass/Fail: (score >= {threshold} is pass)
3. Feedback: If failed, provide specific actionable feedback for improvement
4. Suggestions: What needs to be changed to pass

Format your response as:
Score: <number>/100
Passed: <Yes/No>
Feedback:
- <point 1>
- <point 2>
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
        # If review fails, assume pass to avoid blocking
        return True, f"Review pipeline error (assuming pass): {exc}", 75

    review_text = result.text() if result.output_path.exists() else ""
    score = _parse_quality_score(review_text)
    passed = score >= threshold

    # Extract feedback section
    feedback = review_text
    match = re.search(r"[Ff]eedback:?(.*?)(?:\n\n|\Z)", review_text, re.DOTALL)
    if match:
        feedback = match.group(1).strip()

    return passed, feedback, score


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


def pr_kernel(
    state: ImplState,
    session: Session | None,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> tuple[bool, str, str | None, str | None]:
    """Create pull request for the implementation.

    Args:
        state: Current workflow state with finalize content.
        session: Optional session (not used, kept for signature consistency).
        push_remote: Remote to push to (auto-detected if None).
        base_branch: Base branch for PR (auto-detected if None).

    Returns:
        Tuple of (success, message, pr_number, pr_url) where:
        - success: True if PR was created successfully
        - message: PR URL on success, error message on failure
        - pr_number: PR number as string if created, None otherwise
        - pr_url: Full PR URL if created, None otherwise
    """
    from agentize.workflow.impl.impl import ImplError, _validate_pr_title

    tmp_dir = state.worktree / ".tmp"
    finalize_file = tmp_dir / "finalize.txt"

    # Auto-detect remote and base branch if not provided
    if not push_remote:
        push_remote = _detect_push_remote(state.worktree)
    if not base_branch:
        base_branch = _detect_base_branch(state.worktree, push_remote)

    branch_name = _current_branch(state.worktree)

    # Push branch
    cmd_parts: list[str | Path] = ["git", "push", "-u", push_remote, branch_name]
    push_cmd = _shell_cmd(cmd_parts)
    push_result = run_shell_function(push_cmd, cwd=state.worktree)
    if push_result.returncode != 0:
        print(
            f"Warning: Failed to push branch to {push_remote}",
            file=sys.stderr,
        )
        # Continue anyway, PR might still be creatable

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
        return False, str(exc), None, None

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
        return True, pr_url or f"PR #{pr_number} created", pr_number, pr_url
    except RuntimeError as exc:
        return False, f"Failed to create PR: {exc}", None, None
