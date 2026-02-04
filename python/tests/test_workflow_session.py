"""Tests for the Session DSL in agentize.workflow.api."""

import subprocess
import threading
from pathlib import Path

import pytest

try:
    from agentize.workflow.api import PipelineError, Session, StageResult
except ImportError:
    PipelineError = None
    Session = None
    StageResult = None


@pytest.mark.skipif(Session is None, reason="Implementation not yet available")
def test_run_prompt_retries_on_missing_output(tmp_path: Path):
    """run_prompt retries when output is missing and succeeds on retry."""
    calls: list[dict[str, str]] = []

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
        calls.append({"provider": provider, "model": model})
        if len(calls) == 1:
            return subprocess.CompletedProcess(args=["stub"], returncode=0)
        Path(output_file).write_text("ok")
        return subprocess.CompletedProcess(args=["stub"], returncode=0)

    session = Session(output_dir=tmp_path, prefix="retry", runner=_runner)
    result = session.run_prompt(
        "stage",
        "hello",
        ("claude", "sonnet"),
        retry=1,
        retry_delay=0,
    )

    assert result.output_path.exists()
    assert result.output_path.read_text().strip() == "ok"
    assert len(calls) == 2


@pytest.mark.skipif(PipelineError is None or Session is None, reason="Implementation not yet available")
def test_run_prompt_raises_after_retries(tmp_path: Path):
    """run_prompt raises PipelineError after exhausting retries."""
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
        return subprocess.CompletedProcess(args=["stub"], returncode=1)

    session = Session(output_dir=tmp_path, prefix="fail", runner=_runner)

    with pytest.raises(PipelineError):
        session.run_prompt(
            "stage",
            "hello",
            ("claude", "sonnet"),
            retry=1,
            retry_delay=0,
        )


@pytest.mark.skipif(StageResult is None, reason="Implementation not yet available")
def test_stage_result_text_reads_output(tmp_path: Path):
    """StageResult.text returns the output file contents."""
    output_path = tmp_path / "output.md"
    output_path.write_text("content")
    result = StageResult(
        stage="test",
        input_path=tmp_path / "input.md",
        output_path=output_path,
        process=subprocess.CompletedProcess(args=[], returncode=0),
    )

    assert result.text() == "content"


@pytest.mark.skipif(Session is None, reason="Implementation not yet available")
def test_run_parallel_returns_mapping(tmp_path: Path):
    """run_parallel returns results keyed by stage name."""
    lock = threading.Lock()
    seen: list[str] = []

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
        with lock:
            seen.append(str(output_file))
        Path(output_file).write_text(f"done:{Path(output_file).name}")
        return subprocess.CompletedProcess(args=["stub"], returncode=0)

    session = Session(output_dir=tmp_path, prefix="parallel", runner=_runner)
    calls = [
        session.stage("critique", "prompt A", ("claude", "opus")),
        session.stage("reducer", "prompt B", ("claude", "opus")),
    ]

    results = session.run_parallel(calls, max_workers=2)

    assert set(results.keys()) == {"critique", "reducer"}
    assert results["critique"].text().startswith("done:")
    assert results["reducer"].text().startswith("done:")
    assert len(seen) == 2
