"""Reusable TTY and shell invocation utilities for workflow orchestration.

Provides:
- PlannerTTY: Terminal output helper with animation and timing support
- run_acw: Wrapper around the acw shell function
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional

from agentize.shell import get_agentize_home


# ============================================================
# TTY Output Helpers
# ============================================================


class PlannerTTY:
    """TTY output helper that mirrors planner pipeline styling."""

    def __init__(self, *, verbose: bool = False) -> None:
        self.verbose = verbose
        self._anim_thread: Optional[threading.Thread] = None
        self._anim_stop: Optional[threading.Event] = None

    @staticmethod
    def _color_enabled() -> bool:
        return (
            os.getenv("NO_COLOR") is None
            and os.getenv("PLANNER_NO_COLOR") is None
            and sys.stderr.isatty()
        )

    @staticmethod
    def _anim_enabled() -> bool:
        return os.getenv("PLANNER_NO_ANIM") is None and sys.stderr.isatty()

    def _clear_line(self) -> None:
        sys.stderr.write("\r\033[K")
        sys.stderr.flush()

    def term_label(self, label: str, text: str, style: str = "") -> None:
        if not self._color_enabled():
            print(f"{label} {text}", file=sys.stderr)
            return

        color_code = ""
        if style == "info":
            color_code = "\033[1;36m"
        elif style == "success":
            color_code = "\033[1;32m"
        else:
            print(f"{label} {text}", file=sys.stderr)
            return

        sys.stderr.write(f"{color_code}{label}\033[0m {text}\n")
        sys.stderr.flush()

    def print_feature(self, desc: str) -> None:
        self.term_label("Feature:", desc, "info")

    def stage(self, message: str) -> None:
        print(message, file=sys.stderr)

    def log(self, message: str) -> None:
        if self.verbose:
            print(message, file=sys.stderr)

    def timer_start(self) -> float:
        return time.time()

    def timer_log(self, stage: str, start_epoch: float, backend: str | None = None) -> None:
        elapsed = int(time.time() - start_epoch)
        if backend:
            print(f"  agent {stage} ({backend}) runs {elapsed}s", file=sys.stderr)
        else:
            print(f"  agent {stage} runs {elapsed}s", file=sys.stderr)

    def anim_start(self, label: str) -> None:
        if not self._anim_enabled():
            print(label, file=sys.stderr)
            return

        self.anim_stop()
        stop_event = threading.Event()

        def _run() -> None:
            dots = ".."
            growing = True
            while not stop_event.is_set():
                self._clear_line()
                sys.stderr.write(f"{label} {dots}")
                sys.stderr.flush()
                time.sleep(0.4)
                if growing:
                    dots += "."
                    if len(dots) >= 5:
                        growing = False
                else:
                    dots = dots[:-1]
                    if len(dots) <= 2:
                        growing = True

        thread = threading.Thread(target=_run, daemon=True)
        self._anim_stop = stop_event
        self._anim_thread = thread
        thread.start()

    def anim_stop(self) -> None:
        if self._anim_thread and self._anim_stop:
            self._anim_stop.set()
            self._anim_thread.join(timeout=1)
            self._anim_thread = None
            self._anim_stop = None
            self._clear_line()


# ============================================================
# ACW Wrapper
# ============================================================


def run_acw(
    provider: str,
    model: str,
    input_file: str | Path,
    output_file: str | Path,
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
) -> subprocess.CompletedProcess:
    """Run acw shell function for a single stage.

    Args:
        provider: Backend provider (e.g., "claude", "codex")
        model: Model identifier (e.g., "sonnet", "opus")
        input_file: Path to input prompt file
        output_file: Path for stage output
        tools: Tool configuration (Claude provider only)
        permission_mode: Permission mode override (Claude provider only)
        extra_flags: Additional CLI flags
        timeout: Execution timeout in seconds (default: 900)

    Returns:
        subprocess.CompletedProcess with stdout/stderr captured

    Raises:
        subprocess.TimeoutExpired: If execution exceeds timeout
    """
    agentize_home = get_agentize_home()
    acw_script = os.environ.get("PLANNER_ACW_SCRIPT")
    if not acw_script:
        acw_script = os.path.join(agentize_home, "src", "cli", "acw.sh")

    # Build command arguments
    cmd_parts = [provider, model, str(input_file), str(output_file)]

    # Add Claude-specific flags
    if provider == "claude":
        if tools:
            cmd_parts.extend(["--tools", tools])
        if permission_mode:
            cmd_parts.extend(["--permission-mode", permission_mode])

    # Add extra flags
    if extra_flags:
        cmd_parts.extend(extra_flags)

    # Quote paths to handle spaces
    cmd_args = " ".join(f'"{arg}"' for arg in cmd_parts)
    bash_cmd = f'source "{acw_script}" && acw {cmd_args}'

    # Set up environment
    env = os.environ.copy()
    env["AGENTIZE_HOME"] = agentize_home

    return subprocess.run(
        ["bash", "-c", bash_cmd],
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


__all__ = ["PlannerTTY", "run_acw"]
