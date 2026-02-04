"""Session DSL for running staged workflows with ACW."""

from __future__ import annotations

import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable

from agentize.workflow.api.acw import ACW, run_acw

PromptWriter = Callable[[Path], str]
PromptInput = str | PromptWriter


@dataclass(frozen=True)
class StageResult:
    """Result for a single pipeline stage."""

    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess

    def text(self) -> str:
        return self.output_path.read_text()


@dataclass(frozen=True)
class StageCall:
    """Call specification for a stage executed in run_parallel."""

    stage: str
    prompt: PromptInput
    backend: tuple[str, str]
    options: dict[str, Any]


class PipelineError(RuntimeError):
    """Raised when a stage exhausts its retry budget."""

    def __init__(self, stage: str, attempts: int, last_error: Exception | str) -> None:
        self.stage = stage
        self.attempts = attempts
        self.last_error = last_error
        detail = last_error if isinstance(last_error, str) else str(last_error)
        super().__init__(f"Stage '{stage}' failed after {attempts} attempts: {detail}")


class Session:
    """Imperative workflow session with shared artifact settings."""

    def __init__(
        self,
        output_dir: str | Path,
        prefix: str,
        *,
        runner: Callable[..., subprocess.CompletedProcess] = run_acw,
        input_suffix: str = "-input.md",
        output_suffix: str = "-output.md",
    ) -> None:
        self._output_dir = Path(output_dir)
        self._output_dir.mkdir(parents=True, exist_ok=True)
        self._prefix = prefix
        self._runner = runner
        self._input_suffix = input_suffix
        self._output_suffix = output_suffix
        self._log_lock = threading.Lock()

    def _log(self, message: str) -> None:
        with self._log_lock:
            print(message, file=sys.stderr)

    def _normalize_path(self, path: str | Path) -> Path:
        path = Path(path)
        if path.is_absolute():
            return path
        return self._output_dir / path

    def _resolve_paths(
        self,
        stage: str,
        input_path: str | Path | None,
        output_path: str | Path | None,
    ) -> tuple[Path, Path]:
        if input_path is None:
            resolved_input = self._output_dir / f"{self._prefix}-{stage}{self._input_suffix}"
        else:
            resolved_input = self._normalize_path(input_path)

        if output_path is None:
            resolved_output = self._output_dir / f"{self._prefix}-{stage}{self._output_suffix}"
        else:
            resolved_output = self._normalize_path(output_path)

        return resolved_input, resolved_output

    def _write_prompt(self, prompt: PromptInput, input_path: Path) -> None:
        if callable(prompt):
            rendered = prompt(input_path)
            if not input_path.exists():
                if rendered is None:
                    raise ValueError(
                        "Prompt writer did not write input file or return content"
                    )
                input_path.write_text(rendered)
            return
        if not isinstance(prompt, str):
            raise TypeError("prompt must be a string or a callable writer")
        input_path.write_text(prompt)

    def _run_stage(
        self,
        name: str,
        backend: tuple[str, str],
        input_path: Path,
        output_path: Path,
        *,
        tools: str | None,
        permission_mode: str | None,
        timeout: int,
        extra_flags: list[str] | None,
    ) -> subprocess.CompletedProcess:
        provider, model = backend
        acw_runner = ACW(
            name=name,
            provider=provider,
            model=model,
            timeout=timeout,
            tools=tools,
            permission_mode=permission_mode,
            extra_flags=extra_flags,
            log_writer=self._log,
            runner=self._runner,
        )
        return acw_runner.run(input_path, output_path)

    def _validate_output(self, stage: str, output_path: Path, process: subprocess.CompletedProcess) -> None:
        if process.returncode != 0:
            raise RuntimeError(
                f"Stage '{stage}' failed with exit code {process.returncode}"
            )
        if not output_path.exists() or output_path.stat().st_size == 0:
            raise RuntimeError(f"Stage '{stage}' produced no output")

    def run_prompt(
        self,
        name: str,
        prompt: PromptInput,
        backend: tuple[str, str],
        *,
        tools: str | None = None,
        permission_mode: str | None = None,
        timeout: int = 3600,
        extra_flags: list[str] | None = None,
        retry: int = 0,
        retry_delay: float = 0,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> StageResult:
        input_path_resolved, output_path_resolved = self._resolve_paths(
            name, input_path, output_path
        )

        attempts = 0
        last_error: Exception | str = ""

        for attempt in range(1, retry + 2):
            attempts = attempt
            try:
                self._write_prompt(prompt, input_path_resolved)
                process = self._run_stage(
                    name,
                    backend,
                    input_path_resolved,
                    output_path_resolved,
                    tools=tools,
                    permission_mode=permission_mode,
                    timeout=timeout,
                    extra_flags=extra_flags,
                )
                self._validate_output(name, output_path_resolved, process)
                return StageResult(
                    stage=name,
                    input_path=input_path_resolved,
                    output_path=output_path_resolved,
                    process=process,
                )
            except Exception as exc:
                last_error = exc
                if attempt <= retry and retry_delay > 0:
                    time.sleep(retry_delay)

        raise PipelineError(name, attempts, last_error)

    def stage(
        self,
        name: str,
        prompt: PromptInput,
        backend: tuple[str, str],
        **opts: Any,
    ) -> StageCall:
        if "retry" in opts or "retry_delay" in opts:
            raise ValueError("retry and retry_delay are configured on run_parallel")
        return StageCall(stage=name, prompt=prompt, backend=backend, options=opts)

    def run_parallel(
        self,
        calls: Iterable[StageCall],
        *,
        max_workers: int = 2,
        retry: int = 0,
        retry_delay: float = 0,
    ) -> dict[str, StageResult]:
        results: dict[str, StageResult] = {}
        futures = {}
        stage_names: set[str] = set()

        from concurrent.futures import ThreadPoolExecutor

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            for call in calls:
                if call.stage in stage_names:
                    raise ValueError(f"Duplicate stage name '{call.stage}'")
                stage_names.add(call.stage)
                futures[executor.submit(
                    self.run_prompt,
                    call.stage,
                    call.prompt,
                    call.backend,
                    retry=retry,
                    retry_delay=retry_delay,
                    **call.options,
                )] = call.stage

            for future, stage in list(futures.items()):
                result = future.result()
                results[stage] = result

        return results


__all__ = ["Session", "StageCall", "StageResult", "PipelineError"]
