"""GitHub CLI helpers for workflow orchestration."""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable


def _resolve_overrides() -> Path | None:
    overrides_path = os.environ.get("AGENTIZE_SHELL_OVERRIDES")
    if not overrides_path:
        return None
    candidate = Path(overrides_path).expanduser()
    if not candidate.exists():
        return None
    return candidate


def _shell_command(parts: Iterable[str]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def _body_args(body: str) -> tuple[list[str], str | None]:
    if "\n" in body or "\r" in body:
        handle = tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8")
        handle.write(body)
        handle.close()
        return ["--body-file", handle.name], handle.name
    return ["--body", body], None


def _gh_available() -> bool:
    overrides = _resolve_overrides()
    if overrides is None and shutil.which("gh") is None:
        return False
    if overrides is not None:
        cmd = _shell_command(["gh", "auth", "status"])
        result = subprocess.run(
            ["bash", "-c", f"source {shlex.quote(str(overrides))} && {cmd}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0

    result = subprocess.run(
        ["gh", "auth", "status"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _run_gh(
    args: Iterable[str],
    *,
    cwd: str | Path | None = None,
) -> subprocess.CompletedProcess:
    if not _gh_available():
        raise RuntimeError("gh CLI not available or not authenticated")
    overrides = _resolve_overrides()
    if overrides is not None:
        cmd = _shell_command(["gh", *args])
        result = subprocess.run(
            ["bash", "-c", f"source {shlex.quote(str(overrides))} && {cmd}"],
            capture_output=True,
            text=True,
            cwd=str(cwd) if cwd else None,
        )
    else:
        result = subprocess.run(
            ["gh", *args],
            capture_output=True,
            text=True,
            cwd=str(cwd) if cwd else None,
        )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        hint = detail if detail else f"exit code {result.returncode}"
        raise RuntimeError(f"gh {' '.join(args)} failed ({hint})")
    return result


def _parse_issue_number(issue_url: str) -> str | None:
    match = re.search(r"([0-9]+)$", issue_url.strip())
    if not match:
        return None
    return match.group(1)


def issue_create(
    title: str,
    body: str,
    labels: list[str] | None = None,
    *,
    cwd: str | Path | None = None,
) -> tuple[str | None, str]:
    body_args, temp_body = _body_args(body)
    args = ["issue", "create", "--title", title, *body_args]
    if labels:
        args.extend(["--label", ",".join(labels)])
    try:
        result = _run_gh(args, cwd=cwd)
    finally:
        if temp_body:
            Path(temp_body).unlink(missing_ok=True)
    issue_url = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ""
    if not issue_url:
        raise RuntimeError("gh issue create returned no URL")
    return _parse_issue_number(issue_url), issue_url


def issue_view(issue_number: str | int, query: str, *, cwd: str | Path | None = None) -> str:
    result = _run_gh(
        [
            "issue",
            "view",
            str(issue_number),
            "--json",
            "title,body,labels",
            "-q",
            query,
        ],
        cwd=cwd,
    )
    return result.stdout


def issue_body(issue_number: str | int, *, cwd: str | Path | None = None) -> str:
    result = _run_gh(
        ["issue", "view", str(issue_number), "--json", "body", "-q", ".body"],
        cwd=cwd,
    )
    return result.stdout


def issue_url(issue_number: str | int, *, cwd: str | Path | None = None) -> str | None:
    result = _run_gh(
        ["issue", "view", str(issue_number), "--json", "url", "-q", ".url"],
        cwd=cwd,
    )
    url = result.stdout.strip()
    return url if url else None


def issue_edit(
    issue_number: str | int,
    *,
    title: str | None = None,
    body: str | None = None,
    body_file: str | Path | None = None,
    add_labels: list[str] | None = None,
    cwd: str | Path | None = None,
) -> None:
    args = ["issue", "edit", str(issue_number)]
    if title:
        args.extend(["--title", title])
    if body is not None:
        args.extend(["--body", body])
    if body_file is not None:
        args.extend(["--body-file", str(body_file)])
    if add_labels:
        args.extend(["--add-label", ",".join(add_labels)])
    _run_gh(args, cwd=cwd)


def label_create(
    name: str,
    color: str,
    description: str = "",
    *,
    cwd: str | Path | None = None,
) -> None:
    args = ["label", "create", name, "--color", color, "--force"]
    if description:
        args.extend(["--description", description])
    _run_gh(args, cwd=cwd)


def label_add(
    issue_number: str | int,
    labels: list[str],
    *,
    cwd: str | Path | None = None,
) -> None:
    if not labels:
        return
    _run_gh(
        ["issue", "edit", str(issue_number), "--add-label", ",".join(labels)],
        cwd=cwd,
    )


def pr_create(
    title: str,
    body: str,
    *,
    draft: bool = False,
    base: str | None = None,
    head: str | None = None,
    cwd: str | Path | None = None,
) -> str:
    body_args, temp_body = _body_args(body)
    args = ["pr", "create", "--title", title, *body_args]
    if draft:
        args.append("--draft")
    if base:
        args.extend(["--base", base])
    if head:
        args.extend(["--head", head])
    try:
        result = _run_gh(args, cwd=cwd)
    finally:
        if temp_body:
            Path(temp_body).unlink(missing_ok=True)
    pr_url = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ""
    if not pr_url:
        raise RuntimeError("gh pr create returned no URL")
    return pr_url


__all__ = [
    "issue_create",
    "issue_view",
    "issue_body",
    "issue_url",
    "issue_edit",
    "label_create",
    "label_add",
    "pr_create",
]
