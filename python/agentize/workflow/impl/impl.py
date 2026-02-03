"""Python implementation of the lol impl workflow."""

from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path
from typing import Iterable

from agentize.shell import run_shell_function
from agentize.workflow.utils import ACW


class ImplError(RuntimeError):
    """Workflow error for the impl loop."""


_REQUIRED_PLACEHOLDERS = {
    "{{issue_no}}",
    "{{issue_file}}",
    "{{finalize_file}}",
    "{{iteration_section}}",
    "{{previous_output_section}}",
    "{{previous_commit_report_section}}",
}


def rel_path(path: str | Path) -> Path:
    """Resolve a path relative to this module's directory."""
    base_dir = Path(__file__).resolve().parent
    candidate = Path(path)
    return candidate if candidate.is_absolute() else base_dir / candidate


def _shell_cmd(parts: Iterable[str | Path]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def _read_template() -> str:
    template_path = rel_path("continue-prompt.md")
    if not template_path.exists():
        raise ImplError(f"Error: Missing prompt template at {template_path}")
    return template_path.read_text()


def _validate_placeholders(template: str) -> None:
    missing = sorted(p for p in _REQUIRED_PLACEHOLDERS if p not in template)
    if missing:
        missing_list = ", ".join(missing)
        raise ImplError(f"Error: Prompt template missing placeholders: {missing_list}")


def _iteration_section(iteration: int | None) -> str:
    if iteration is None:
        return ""
    return (
        f"Current iteration: {iteration}\n"
        f"Create .tmp/commit-report-iter-{iteration}.txt for this iteration.\n"
    )


def _section(title: str, content: str | None) -> str:
    if not content:
        return ""
    return f"\n\n---\n{title}\n{content.rstrip()}\n"


def render_prompt(
    template: str,
    *,
    issue_no: int,
    issue_file: Path,
    finalize_file: Path,
    iteration: int | None = None,
    previous_output: str | None = None,
    previous_commit_report: str | None = None,
) -> str:
    """Render an iteration prompt from the template."""
    _validate_placeholders(template)

    replacements = {
        "{{issue_no}}": str(issue_no),
        "{{issue_file}}": str(issue_file),
        "{{finalize_file}}": str(finalize_file),
        "{{iteration_section}}": _iteration_section(iteration),
        "{{previous_output_section}}": _section(
            "Output from last iteration:",
            previous_output,
        ),
        "{{previous_commit_report_section}}": _section(
            "Previous iteration summary (commit report):",
            previous_commit_report,
        ),
    }

    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(key, value)

    return rendered


def _read_optional(path: Path) -> str | None:
    if path.exists() and path.is_file():
        content = path.read_text()
        if content.strip():
            return content
    return None


def _prefetch_issue(issue_no: int, issue_file: Path, *, cwd: Path) -> None:
    query = (
        '("# " + .title + "\\n\\n" + '
        '(if (.labels|length)>0 then "Labels: " + '
        '(.labels|map(.name)|join(", ")) + "\\n\\n" else "" end) + '
        '.body + "\\n")'
    )
    cmd = _shell_cmd([
        "gh",
        "issue",
        "view",
        str(issue_no),
        "--json",
        "title,body,labels",
        "-q",
        query,
    ])
    result = run_shell_function(cmd, capture_output=True, cwd=cwd)
    if result.returncode != 0 or not result.stdout.strip():
        if issue_file.exists():
            issue_file.unlink()
        raise ImplError(f"Error: Failed to fetch issue content for issue #{issue_no}")

    issue_file.write_text(result.stdout)


def _completion_marker_present(finalize_file: Path, issue_no: int) -> bool:
    if not finalize_file.exists():
        return False
    content = finalize_file.read_text()
    return f"Issue {issue_no} resolved" in content


def _stage_and_commit(worktree_path: Path, commit_report_file: Path, iteration: int) -> None:
    add_result = run_shell_function("git add -A", cwd=worktree_path)
    if add_result.returncode != 0:
        raise ImplError(f"Error: Failed to stage changes for iteration {iteration}")

    diff_result = run_shell_function(
        "git diff --cached --quiet",
        cwd=worktree_path,
    )
    if diff_result.returncode == 0:
        print(f"No changes to commit for iteration {iteration}")
        return
    if diff_result.returncode not in (0, 1):
        raise ImplError(f"Error: Failed to check staged changes for iteration {iteration}")

    commit_cmd = _shell_cmd([
        "git",
        "commit",
        "-F",
        str(commit_report_file),
    ])
    commit_result = run_shell_function(commit_cmd, cwd=worktree_path)
    if commit_result.returncode != 0:
        raise ImplError(f"Error: Failed to commit iteration {iteration}")


def _detect_push_remote(worktree_path: Path) -> str:
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


def _sync_branch(worktree_path: Path) -> tuple[str, str]:
    push_remote = _detect_push_remote(worktree_path)
    base_branch = _detect_base_branch(worktree_path, push_remote)
    print(f"Syncing with {push_remote}/{base_branch}...")

    fetch_cmd = _shell_cmd(["git", "fetch", push_remote])
    fetch_result = run_shell_function(fetch_cmd, cwd=worktree_path)
    if fetch_result.returncode != 0:
        raise ImplError(f"Error: Failed to fetch from {push_remote}")

    rebase_cmd = _shell_cmd(["git", "rebase", f"{push_remote}/{base_branch}"])
    rebase_result = run_shell_function(rebase_cmd, cwd=worktree_path)
    if rebase_result.returncode != 0:
        raise ImplError("Error: Rebase conflict detected. Resolve conflicts and rerun.")

    return push_remote, base_branch


def _append_closes_line(finalize_file: Path, issue_no: int) -> None:
    content = finalize_file.read_text()
    if re.search(rf"closes\s+#\s*{issue_no}", content, re.IGNORECASE):
        return
    updated = content.rstrip("\n") + f"\nCloses #{issue_no}\n"
    finalize_file.write_text(updated)


def _push_and_create_pr(
    worktree_path: Path,
    issue_no: int,
    finalize_file: Path,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> None:
    if not push_remote:
        push_remote = _detect_push_remote(worktree_path)
    if not base_branch:
        base_branch = _detect_base_branch(worktree_path, push_remote)

    branch_result = run_shell_function(
        "git branch --show-current",
        capture_output=True,
        cwd=worktree_path,
    )
    branch_name = branch_result.stdout.strip()

    push_cmd = _shell_cmd([
        "git",
        "push",
        "-u",
        push_remote,
        branch_name,
    ])
    push_result = run_shell_function(push_cmd, cwd=worktree_path)
    if push_result.returncode != 0:
        print(f"Warning: Failed to push branch to {push_remote}", file=sys.stderr)

    pr_title = ""
    if finalize_file.exists():
        pr_title = finalize_file.read_text().splitlines()[0].strip()
    if not pr_title:
        pr_title = f"Implement issue #{issue_no}"

    _append_closes_line(finalize_file, issue_no)
    body_file = shlex.quote(str(finalize_file))
    pr_cmd = (
        f"gh pr create --base {shlex.quote(base_branch)} "
        f"--title {shlex.quote(pr_title)} "
        f"--body \"$(cat {body_file})\""
    )
    pr_result = run_shell_function(pr_cmd, cwd=worktree_path)
    if pr_result.returncode != 0:
        print(
            "Warning: Failed to create PR. You may need to create it manually.",
            file=sys.stderr,
        )


def _coerce_issue_no(issue_no: int | str) -> int:
    if isinstance(issue_no, int):
        return issue_no
    if isinstance(issue_no, str) and issue_no.isdigit():
        return int(issue_no)
    raise ValueError("Error: Issue number is required and must be numeric")


def _parse_backend(backend: str) -> tuple[str, str]:
    if ":" not in backend:
        raise ValueError(
            "Error: Backend must be in provider:model format "
            "(e.g., codex:gpt-5.2-codex)"
        )
    provider, model = backend.split(":", 1)
    return provider, model


def _parse_max_iterations(value: int | str) -> int:
    if isinstance(value, int):
        max_iterations = value
    elif isinstance(value, str) and value.isdigit():
        max_iterations = int(value)
    else:
        raise ValueError("Error: --max-iterations must be a positive number")

    if max_iterations <= 0:
        raise ValueError("Error: --max-iterations must be a positive number")

    return max_iterations


def run_impl_workflow(
    issue_no: int,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_iterations: int = 10,
    yolo: bool = False,
) -> None:
    """Run the issue-to-implementation workflow loop."""
    issue_no = _coerce_issue_no(issue_no)
    provider, model = _parse_backend(backend)
    max_iterations = _parse_max_iterations(max_iterations)

    worktree_result = run_shell_function(
        _shell_cmd(["wt", "pathto", str(issue_no)]),
        capture_output=True,
    )
    worktree_path = worktree_result.stdout.strip() if worktree_result.returncode == 0 else ""

    if not worktree_path:
        print(f"Creating worktree for issue {issue_no}...")
        spawn_result = run_shell_function(
            _shell_cmd(["wt", "spawn", str(issue_no), "--no-agent"])
        )
        if spawn_result.returncode != 0:
            raise ImplError(f"Error: Failed to create worktree for issue {issue_no}")
        worktree_result = run_shell_function(
            _shell_cmd(["wt", "pathto", str(issue_no)]),
            capture_output=True,
        )
        worktree_path = worktree_result.stdout.strip()
        if not worktree_path:
            raise ImplError("Error: Failed to get worktree path after spawn")
    else:
        print(f"Using existing worktree for issue {issue_no} at {worktree_path}")

    worktree = Path(worktree_path)
    push_remote, base_branch = _sync_branch(worktree)
    tmp_dir = worktree / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    issue_file = tmp_dir / f"issue-{issue_no}.md"
    base_input_file = tmp_dir / "impl-input-base.txt"
    output_file = tmp_dir / "impl-output.txt"
    finalize_file = tmp_dir / "finalize.txt"

    _prefetch_issue(issue_no, issue_file, cwd=worktree)

    template = _read_template()
    base_prompt = render_prompt(
        template,
        issue_no=issue_no,
        issue_file=issue_file,
        finalize_file=finalize_file,
    )
    base_input_file.write_text(base_prompt)

    completion_found = False

    for iteration in range(1, max_iterations + 1):
        print(f"Iteration {iteration}/{max_iterations}...")
        input_file = tmp_dir / f"impl-input-{iteration}.txt"

        previous_output = _read_optional(output_file)
        prev_commit_report = None
        if iteration > 1:
            prev_commit_report = _read_optional(
                tmp_dir / f"commit-report-iter-{iteration - 1}.txt"
            )

        prompt = render_prompt(
            template,
            issue_no=issue_no,
            issue_file=issue_file,
            finalize_file=finalize_file,
            iteration=iteration,
            previous_output=previous_output,
            previous_commit_report=prev_commit_report,
        )
        input_file.write_text(prompt)

        extra_flags = ["--yolo"] if yolo else None

        def _log_writer(message: str) -> None:
            print(message, file=sys.stderr)

        acw_runner = ACW(
            name=f"impl-iter-{iteration}",
            provider=provider,
            model=model,
            extra_flags=extra_flags,
            log_writer=_log_writer,
        )
        acw_result = acw_runner.run(input_file, output_file)
        if acw_result.returncode != 0:
            print(
                f"Warning: acw exited with non-zero status on iteration {iteration}",
                file=sys.stderr,
            )

        completion_found = _completion_marker_present(finalize_file, issue_no)

        commit_report_file = tmp_dir / f"commit-report-iter-{iteration}.txt"
        commit_report = _read_optional(commit_report_file)
        if not commit_report:
            if completion_found:
                raise ImplError(
                    f"Error: Missing commit report for iteration {iteration}\n"
                    f"Expected: {commit_report_file}"
                )
            print(
                f"Warning: Missing commit report for iteration {iteration}; skipping commit.",
                file=sys.stderr,
            )
            if completion_found:
                break
            continue

        _stage_and_commit(worktree, commit_report_file, iteration)

        if completion_found:
            print("Completion marker found!")
            break

    if not completion_found:
        raise ImplError(
            f"Error: Max iteration limit ({max_iterations}) reached without completion marker\n"
            f"To continue, increase --max-iterations or create {finalize_file} with "
            f"'Issue {issue_no} resolved'"
        )

    _push_and_create_pr(
        worktree,
        issue_no,
        finalize_file,
        push_remote=push_remote,
        base_branch=base_branch,
    )
    print(f"Implementation complete for issue #{issue_no}")
