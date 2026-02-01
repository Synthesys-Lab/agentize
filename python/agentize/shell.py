"""Utilities for invoking shell functions from Python."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Optional


def get_agentize_home() -> str:
    """Get AGENTIZE_HOME from environment or derive from repo root."""
    if "AGENTIZE_HOME" in os.environ:
        return os.environ["AGENTIZE_HOME"]

    # Try to derive from this file's location
    # shell.py is at python/agentize/shell.py, so repo root is ../../..
    shell_path = Path(__file__).resolve()
    repo_root = shell_path.parent.parent.parent
    if (repo_root / "Makefile").exists() and (repo_root / "src" / "cli" / "lol.sh").exists():
        return str(repo_root)

    raise RuntimeError(
        "AGENTIZE_HOME not set and could not be derived.\n"
        "Please set AGENTIZE_HOME to point to your agentize repository."
    )


def run_shell_function(
    cmd: str,
    *,
    capture_output: bool = False,
    agentize_home: Optional[str] = None,
) -> subprocess.CompletedProcess:
    """Run a shell function with AGENTIZE_HOME set.

    Args:
        cmd: The shell command to run (e.g., "wt spawn 123", "_lol_cmd_version")
        capture_output: Whether to capture stdout/stderr
        agentize_home: Override AGENTIZE_HOME (defaults to auto-detection)

    Returns:
        CompletedProcess with result
    """
    home = agentize_home or get_agentize_home()
    env = os.environ.copy()
    env["AGENTIZE_HOME"] = home

    full_cmd = f'source "$AGENTIZE_HOME/setup.sh" && {cmd}'

    return subprocess.run(
        ["bash", "-c", full_cmd],
        env=env,
        capture_output=capture_output,
        text=True,
    )
