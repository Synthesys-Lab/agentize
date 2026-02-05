"""Python implementation of the lol simp workflow."""

from __future__ import annotations

import random
from pathlib import Path

from agentize.shell import get_agentize_home, resolve_repo_root, run_shell_function
from agentize.workflow.api import Session
from agentize.workflow.api import path as path_utils
from agentize.workflow.api import prompt as prompt_utils
from agentize.workflow.api.session import PipelineError


class SimpError(RuntimeError):
    """Workflow error for the simp workflow."""


def rel_path(path: str | Path) -> Path:
    """Resolve a path relative to this module's directory."""
    return path_utils.relpath(__file__, path)


def _parse_backend(backend: str) -> tuple[str, str]:
    if ":" not in backend:
        raise ValueError(
            "Error: Backend must be in provider:model format "
            "(e.g., codex:gpt-5.2-codex)"
        )
    provider, model = backend.split(":", 1)
    return provider, model


def _parse_max_files(value: int | str) -> int:
    if isinstance(value, int):
        max_files = value
    elif isinstance(value, str) and value.isdigit():
        max_files = int(value)
    else:
        raise ValueError("Error: --max-files must be a positive number")

    if max_files <= 0:
        raise ValueError("Error: --max-files must be a positive number")

    return max_files


def _parse_seed(value: int | str | None) -> int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    raise ValueError("Error: --seed must be a number")


def _normalize_file_path(file_path: str, repo_root: Path) -> Path:
    candidate = Path(file_path)
    if not candidate.is_absolute():
        candidate = repo_root / candidate
    candidate = candidate.resolve()
    repo_root = repo_root.resolve()

    try:
        rel = candidate.relative_to(repo_root)
    except ValueError as exc:
        raise SimpError(f"Error: File must be inside repo: {file_path}") from exc

    if not candidate.exists() or not candidate.is_file():
        raise SimpError(f"Error: File not found: {file_path}")

    return rel


def _git_ls_files(repo_root: Path) -> list[str]:
    result = run_shell_function("git ls-files", capture_output=True, cwd=repo_root)
    if result.returncode != 0:
        raise SimpError("Error: Failed to list repository files")
    files = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not files:
        raise SimpError("Error: No tracked files found")
    return files


def _select_files(
    file_path: str | None,
    repo_root: Path,
    *,
    max_files: int,
    seed: int | None,
) -> list[str]:
    if file_path:
        rel = _normalize_file_path(file_path, repo_root)
        return [rel.as_posix()]

    files = _git_ls_files(repo_root)
    rng = random.Random(seed)
    rng.shuffle(files)
    return files[:max_files]


def _format_file_block(path: str, repo_root: Path) -> str:
    full_path = repo_root / path
    if not full_path.exists() or not full_path.is_file():
        raise SimpError(f"Error: File not found: {path}")
    content = full_path.read_text(encoding="utf-8", errors="replace")
    content = content.rstrip("\n")
    return f"### {path}\n```\n{content}\n```"


def _render_prompt(
    prompt_path: Path,
    selected_files: list[str],
    *,
    repo_root: Path,
    dest_path: Path,
) -> str:
    selected_list = "\n".join(f"- {path}" for path in selected_files)
    file_blocks = "\n\n".join(
        _format_file_block(path, repo_root) for path in selected_files
    )
    return prompt_utils.render(
        prompt_path,
        {
            "selected_files": selected_list,
            "file_contents": file_blocks,
        },
        dest_path,
    )


def _resolve_repo_root() -> Path:
    try:
        return Path(get_agentize_home())
    except RuntimeError:
        return resolve_repo_root()


def run_simp_workflow(
    file_path: str | None,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_files: int = 3,
    seed: int | None = None,
) -> None:
    """Run the semantic-preserving simplifier workflow."""
    provider, model = _parse_backend(backend)
    max_files = _parse_max_files(max_files)
    seed = _parse_seed(seed)

    repo_root = _resolve_repo_root()
    tmp_dir = repo_root / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    selected_files = _select_files(
        file_path,
        repo_root,
        max_files=max_files,
        seed=seed,
    )

    if not selected_files:
        raise SimpError("Error: No files selected for simplification")

    targets_path = tmp_dir / "simp-targets.txt"
    targets_path.write_text("\n".join(selected_files) + "\n")

    prompt_path = rel_path("prompt.md")
    input_path = tmp_dir / "simp-input.md"
    output_path = tmp_dir / "simp-output.md"

    prompt_text = _render_prompt(
        prompt_path,
        selected_files,
        repo_root=repo_root,
        dest_path=input_path,
    )

    session = Session(output_dir=tmp_dir, prefix="simp")

    try:
        session.run_prompt(
            "simp",
            prompt_text,
            (provider, model),
            input_path=input_path,
            output_path=output_path,
        )
    except PipelineError as exc:
        raise SimpError(f"Error: simp workflow failed ({exc})") from exc
