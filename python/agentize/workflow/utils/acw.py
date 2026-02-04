"""Reusable shell invocation utilities for workflow orchestration."""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Callable

from agentize.shell import get_agentize_home

_ACW_PROVIDERS_CACHE: list[str] | None = None
_ACW_PROVIDERS_LOCK = threading.Lock()


# ============================================================
# ACW Wrapper
# ============================================================


def _resolve_acw_script(agentize_home: str, env: dict[str, str] | None = None) -> str:
    env_vars = env or os.environ
    acw_script = env_vars.get("PLANNER_ACW_SCRIPT")
    if not acw_script:
        acw_script = os.path.join(agentize_home, "src", "cli", "acw.sh")
    return acw_script


def _resolve_overrides_cmd(env: dict[str, str] | None = None) -> str:
    env_vars = env or os.environ
    overrides_path = env_vars.get("AGENTIZE_SHELL_OVERRIDES")
    if overrides_path:
        override_path = Path(overrides_path).expanduser()
        if override_path.exists():
            return f' && source "{override_path}"'
    return ""


def _merge_env(env: dict[str, str] | None) -> dict[str, str]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    agentize_home = merged.get("AGENTIZE_HOME") or get_agentize_home()
    merged["AGENTIZE_HOME"] = agentize_home
    return merged


def run_acw(
    provider: str,
    model: str,
    input_file: str | Path,
    output_file: str | Path,
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 3600,
    cwd: str | Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
    """Run acw shell function for a single stage."""
    merged_env = _merge_env(env)
    agentize_home = merged_env["AGENTIZE_HOME"]
    acw_script = _resolve_acw_script(agentize_home, merged_env)

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
    overrides_cmd = _resolve_overrides_cmd(merged_env)
    bash_cmd = f'source "{acw_script}"{overrides_cmd} && acw {cmd_args}'

    return subprocess.run(
        ["bash", "-c", bash_cmd],
        env=merged_env,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=str(cwd) if cwd else None,
    )


def list_acw_providers() -> list[str]:
    """List supported providers from `acw --complete providers`."""
    global _ACW_PROVIDERS_CACHE

    if _ACW_PROVIDERS_CACHE is not None:
        return list(_ACW_PROVIDERS_CACHE)

    with _ACW_PROVIDERS_LOCK:
        if _ACW_PROVIDERS_CACHE is not None:
            return list(_ACW_PROVIDERS_CACHE)

        merged_env = _merge_env(None)
        agentize_home = merged_env["AGENTIZE_HOME"]
        acw_script = _resolve_acw_script(agentize_home, merged_env)
        overrides_cmd = _resolve_overrides_cmd(merged_env)
        bash_cmd = f'source "{acw_script}"{overrides_cmd} && acw --complete providers'

        result = subprocess.run(
            ["bash", "-c", bash_cmd],
            env=merged_env,
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
        timeout: int = 3600,
        *,
        tools: str | None = None,
        permission_mode: str | None = None,
        extra_flags: list[str] | None = None,
        log_writer: Callable[[str], None] | None = None,
        runner: Callable[..., subprocess.CompletedProcess] | None = None,
    ) -> None:
        # Skip provider validation when using custom runner (for tests)
        if runner is None:
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
        self._runner = runner if runner is not None else run_acw

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

        process = self._runner(
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


def run(
    input_file: str | Path,
    output_file: str | Path,
    *,
    name: str,
    provider: str,
    model: str,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
    cwd: str | Path | None = None,
    env: dict[str, str] | None = None,
    log_writer: Callable[[str], None] | None = None,
) -> subprocess.CompletedProcess:
    """Run a single ACW stage with timing logs."""

    def _runner(
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
        return run_acw(
            provider,
            model,
            input_file,
            output_file,
            tools=tools,
            permission_mode=permission_mode,
            extra_flags=extra_flags,
            timeout=timeout,
            cwd=cwd,
            env=env,
        )

    runner = ACW(
        name=name,
        provider=provider,
        model=model,
        timeout=timeout,
        tools=tools,
        permission_mode=permission_mode,
        extra_flags=extra_flags,
        log_writer=log_writer,
        runner=_runner,
    )
    return runner.run(input_file, output_file)


__all__ = ["ACW", "list_acw_providers", "run", "run_acw"]
