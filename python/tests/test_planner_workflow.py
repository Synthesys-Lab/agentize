"""Tests for python/agentize/workflow planner module.

Verifies pipeline orchestration with a stub runner (no actual LLM calls).
"""

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable
from unittest.mock import Mock

import pytest


# Import from the module we're testing (will fail until implementation exists)
# Using try/except to allow test file to exist before implementation
try:
    from agentize.workflow import run_planner_pipeline, StageResult
except ImportError:
    # Define stubs for test discovery before implementation
    StageResult = None
    run_planner_pipeline = None


# ============================================================
# Fixtures
# ============================================================

@pytest.fixture
def tmp_output_dir(tmp_path: Path) -> Path:
    """Create a temporary output directory for artifacts."""
    output_dir = tmp_path / "output"
    output_dir.mkdir()
    return output_dir


@pytest.fixture
def stub_runner(tmp_path: Path) -> Callable:
    """Create a stub runner that writes output files and records invocations."""
    invocations = []

    def _stub(
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
        """Stub runner that writes deterministic output and records call."""
        invocations.append({
            "provider": provider,
            "model": model,
            "input_file": str(input_file),
            "output_file": str(output_file),
            "tools": tools,
            "permission_mode": permission_mode,
            "extra_flags": extra_flags,
            "timeout": timeout,
        })

        # Write stub output based on stage name extracted from output path
        output_path = Path(output_file)
        stage = output_path.stem.rsplit("-", 1)[-1]  # e.g., "prefix-bold-output" -> "output"
        if "understander" in str(output_path):
            content = "# Understander Output\n\nContext gathered for feature."
        elif "bold" in str(output_path):
            content = "# Bold Proposal\n\nInnovative approach for feature."
        elif "critique" in str(output_path):
            content = "# Critique\n\nFeasibility analysis of bold proposal."
        elif "reducer" in str(output_path):
            content = "# Reduced Proposal\n\nSimplified approach."
        elif "consensus" in str(output_path):
            content = "# Consensus Plan\n\nBalanced implementation plan."
        else:
            content = f"# Stage Output\n\nOutput for {output_path.name}"

        output_path.write_text(content)

        return subprocess.CompletedProcess(
            args=["stub", str(input_file)],
            returncode=0,
            stdout="",
            stderr="",
        )

    _stub.invocations = invocations
    return _stub


# ============================================================
# Test run_planner_pipeline - Stage Results
# ============================================================

class TestPlannerPipelineStageResults:
    """Tests for run_planner_pipeline returning correct stage results."""

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_returns_all_five_stages(self, tmp_output_dir: Path, stub_runner: Callable):
        """run_planner_pipeline returns StageResult for all five stages."""
        results = run_planner_pipeline(
            "Add user authentication",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        assert len(results) == 5
        expected_stages = ["understander", "bold", "critique", "reducer", "consensus"]
        for stage in expected_stages:
            assert stage in results
            assert isinstance(results[stage], StageResult)

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_stage_result_has_correct_attributes(self, tmp_output_dir: Path, stub_runner: Callable):
        """Each StageResult has stage, input_path, output_path, and process."""
        results = run_planner_pipeline(
            "Add dark mode",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        result = results["bold"]
        assert result.stage == "bold"
        assert isinstance(result.input_path, Path)
        assert isinstance(result.output_path, Path)
        assert isinstance(result.process, subprocess.CompletedProcess)

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_output_files_exist(self, tmp_output_dir: Path, stub_runner: Callable):
        """All stage output files are created in output_dir."""
        results = run_planner_pipeline(
            "Add caching layer",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        for stage, result in results.items():
            assert result.output_path.exists(), f"Output file missing for {stage}"
            assert result.output_path.read_text().strip() != ""


# ============================================================
# Test run_planner_pipeline - Execution Order
# ============================================================

class TestPlannerPipelineExecutionOrder:
    """Tests for correct stage execution order."""

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_sequential_order_when_parallel_disabled(self, tmp_output_dir: Path, stub_runner: Callable):
        """With parallel=False, stages run in deterministic order."""
        run_planner_pipeline(
            "Add feature X",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            parallel=False,
            prefix="test",
        )

        invocations = stub_runner.invocations
        # Extract stage names from output file paths
        stages = []
        for inv in invocations:
            output_path = inv["output_file"]
            for stage in ["understander", "bold", "critique", "reducer", "consensus"]:
                if stage in output_path:
                    stages.append(stage)
                    break

        expected_order = ["understander", "bold", "critique", "reducer", "consensus"]
        assert stages == expected_order

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_understander_runs_before_bold(self, tmp_output_dir: Path, stub_runner: Callable):
        """Understander always runs before bold (even with parallel=True)."""
        run_planner_pipeline(
            "Add feature Y",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            parallel=True,
            prefix="test",
        )

        invocations = stub_runner.invocations
        understander_idx = None
        bold_idx = None

        for idx, inv in enumerate(invocations):
            if "understander" in inv["output_file"] and understander_idx is None:
                understander_idx = idx
            if "bold" in inv["output_file"] and bold_idx is None:
                bold_idx = idx

        assert understander_idx is not None, "Understander stage not found in invocations"
        assert bold_idx is not None, "Bold stage not found in invocations"
        assert understander_idx < bold_idx, f"Understander ({understander_idx}) should run before bold ({bold_idx})"


# ============================================================
# Test run_planner_pipeline - Prompt Rendering
# ============================================================

class TestPlannerPipelinePromptRendering:
    """Tests for correct prompt rendering."""

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_feature_description_in_prompts(self, tmp_output_dir: Path, stub_runner: Callable):
        """Feature description appears in rendered input prompts."""
        feature_desc = "Implement JWT authentication with refresh tokens"

        results = run_planner_pipeline(
            feature_desc,
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        # Check that feature description is in understander input
        understander_input = results["understander"].input_path.read_text()
        assert feature_desc in understander_input

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_previous_output_in_chained_stages(self, tmp_output_dir: Path, stub_runner: Callable):
        """Bold stage input includes understander output."""
        results = run_planner_pipeline(
            "Add feature Z",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        bold_input = results["bold"].input_path.read_text()
        # Bold input should reference previous stage output
        assert "Previous Stage Output" in bold_input or "Understander" in bold_input

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_consensus_includes_combined_report(self, tmp_output_dir: Path, stub_runner: Callable):
        """Consensus stage input includes bold, critique, and reducer outputs."""
        results = run_planner_pipeline(
            "Add logging system",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
        )

        consensus_input = results["consensus"].input_path.read_text()
        # Consensus should have combined report from all prior stages
        assert "Bold" in consensus_input or "Proposal" in consensus_input


# ============================================================
# Test run_planner_pipeline - Artifact Naming
# ============================================================

class TestPlannerPipelineArtifactNaming:
    """Tests for artifact file naming."""

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_custom_prefix_used(self, tmp_output_dir: Path, stub_runner: Callable):
        """Custom prefix is used in artifact filenames."""
        results = run_planner_pipeline(
            "Add metrics",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="custom-prefix",
        )

        for stage, result in results.items():
            assert "custom-prefix" in result.input_path.name
            assert "custom-prefix" in result.output_path.name

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_default_prefix_is_timestamp(self, tmp_output_dir: Path, stub_runner: Callable):
        """Default prefix is timestamp-based when not specified."""
        results = run_planner_pipeline(
            "Add alerts",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            # No prefix specified
        )

        # Check that some prefix exists (should be timestamp format)
        understander_result = results["understander"]
        filename = understander_result.input_path.name
        # Filename should have a prefix before "-understander-input.md"
        assert "-understander-input.md" in filename
        prefix = filename.replace("-understander-input.md", "")
        assert len(prefix) > 0  # Some prefix exists


# ============================================================
# Test run_planner_pipeline - New Options
# ============================================================

class TestPlannerPipelineOptions:
    """Tests for output suffix and skip-consensus behavior."""

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_output_suffix_txt(self, tmp_output_dir: Path, stub_runner: Callable):
        """Custom output_suffix changes output filenames."""
        results = run_planner_pipeline(
            "Add planner output suffix",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
            output_suffix=".txt",
        )

        for stage, result in results.items():
            assert result.output_path.name == f"test-{stage}.txt"

    @pytest.mark.skipif(run_planner_pipeline is None, reason="Implementation not yet available")
    def test_skip_consensus(self, tmp_output_dir: Path, stub_runner: Callable):
        """skip_consensus=True omits consensus stage execution."""
        results = run_planner_pipeline(
            "Skip consensus stage",
            output_dir=tmp_output_dir,
            runner=stub_runner,
            prefix="test",
            skip_consensus=True,
        )

        assert "consensus" not in results
        output_files = [Path(inv["output_file"]).name for inv in stub_runner.invocations]
        assert not any("consensus" in output_file for output_file in output_files)


# ============================================================
# Test StageResult dataclass
# ============================================================

class TestStageResult:
    """Tests for StageResult dataclass."""

    @pytest.mark.skipif(StageResult is None, reason="Implementation not yet available")
    def test_stage_result_is_dataclass(self):
        """StageResult is a dataclass with expected fields."""
        from dataclasses import fields

        field_names = [f.name for f in fields(StageResult)]
        assert "stage" in field_names
        assert "input_path" in field_names
        assert "output_path" in field_names
        assert "process" in field_names

    @pytest.mark.skipif(StageResult is None, reason="Implementation not yet available")
    def test_stage_result_creation(self, tmp_path: Path):
        """StageResult can be instantiated with correct fields."""
        proc = subprocess.CompletedProcess(args=[], returncode=0)
        result = StageResult(
            stage="test",
            input_path=tmp_path / "input.md",
            output_path=tmp_path / "output.md",
            process=proc,
        )

        assert result.stage == "test"
        assert result.input_path == tmp_path / "input.md"
        assert result.output_path == tmp_path / "output.md"
        assert result.process.returncode == 0
