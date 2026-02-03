"""Reusable TTY and shell invocation utilities for workflow orchestration.

Provides:
- PlannerTTY: Terminal output helper with animation and timing support
- run_acw: Wrapper around the acw shell function
- list_acw_providers: Provider list resolver via acw completion
- ACW: Class-based runner with provider validation and timing logs
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Callable, Optional

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
    acw_script = _resolve_acw_script(agentize_home)

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
    overrides_cmd = _resolve_overrides_cmd()
    bash_cmd = f'source "{acw_script}"{overrides_cmd} && acw {cmd_args}'

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

_ACW_PROVIDERS_CACHE: list[str] | None = None
_ACW_PROVIDERS_LOCK = threading.Lock()


def _resolve_acw_script(agentize_home: str) -> str:
    acw_script = os.environ.get("PLANNER_ACW_SCRIPT")
    if not acw_script:
        acw_script = os.path.join(agentize_home, "src", "cli", "acw.sh")
    return acw_script


def _resolve_overrides_cmd() -> str:
    overrides_path = os.environ.get("AGENTIZE_SHELL_OVERRIDES")
    if overrides_path:
        override_path = Path(overrides_path).expanduser()
        if override_path.exists():
            return f' && source "{override_path}"'
    return ""


def list_acw_providers() -> list[str]:
    """List supported providers from `acw --complete providers`."""
    global _ACW_PROVIDERS_CACHE

    if _ACW_PROVIDERS_CACHE is not None:
        return list(_ACW_PROVIDERS_CACHE)

    with _ACW_PROVIDERS_LOCK:
        if _ACW_PROVIDERS_CACHE is not None:
            return list(_ACW_PROVIDERS_CACHE)

        agentize_home = get_agentize_home()
        acw_script = _resolve_acw_script(agentize_home)
        overrides_cmd = _resolve_overrides_cmd()
        bash_cmd = f'source "{acw_script}"{overrides_cmd} && acw --complete providers'

        env = os.environ.copy()
        env["AGENTIZE_HOME"] = agentize_home

        result = subprocess.run(
            ["bash", "-c", bash_cmd],
            env=env,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            hint = detail if detail else f"exit code {result.returncode}"
            raise RuntimeError(f"acw --complete providers failed ({hint})")

        providers = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if not providers:
            raise RuntimeError("acw --complete providers returned no providers")

        _ACW_PROVIDERS_CACHE = providers
        return list(providers)


class ACW:
    """Class-based runner for ACW with provider validation and timing logs."""

    def __init__(
        self,
        name: str,
        provider: str,
        model: str,
        timeout: int = 900,
        *,
        tools: str | None = None,
        permission_mode: str | None = None,
        extra_flags: list[str] | None = None,
        log_writer: Callable[[str], None] | None = None,
    ) -> None:
        providers = list_acw_providers()
        if provider not in providers:
            available = ", ".join(providers)
            raise ValueError(f"Unsupported provider '{provider}'. Available: {available}")

        self.name = name
        self.provider = provider
        self.model = model
        self.timeout = timeout
        self.tools = tools
        self.permission_mode = permission_mode
        self.extra_flags = extra_flags
        self._log_writer = log_writer

    def _log(self, message: str) -> None:
        if self._log_writer:
            self._log_writer(message)
            return
        print(message, file=sys.stderr)

    def run(
        self,
        input_file: str | Path,
        output_file: str | Path,
    ) -> subprocess.CompletedProcess:
        start_time = time.time()
        backend = f"{self.provider}:{self.model}"
        self._log(f"agent {self.name} ({backend}) is running...")

        process = run_acw(
            self.provider,
            self.model,
            input_file,
            output_file,
            tools=self.tools,
            permission_mode=self.permission_mode,
            extra_flags=self.extra_flags,
            timeout=self.timeout,
        )

        elapsed = int(time.time() - start_time)
        self._log(f"agent {self.name} ({backend}) runs {elapsed}s")
        return process


__all__ = ["ACW", "PlannerTTY", "list_acw_providers", "run_acw"]
