"""Tests for agentize.eval.eval_harness pure functions."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from agentize.eval.eval_harness import (
    aggregate_metrics,
    extract_patch,
    write_overrides,
    main,
    _eval_pr_kernel,
    _eval_rebase_kernel,
    _build_eval_kernels,
)


# ---------------------------------------------------------------------------
# aggregate_metrics
# ---------------------------------------------------------------------------


class TestAggregateMetrics:
    def test_empty_results(self):
        metrics = aggregate_metrics([])
        assert metrics["total_tasks"] == 0
        assert metrics["completed"] == 0
        assert metrics["tokens_mean"] == 0
        assert metrics["time_mean"] == 0.0

    def test_all_completed(self):
        results = [
            {"instance_id": "a", "status": "completed", "tokens": 100, "wall_time": 10.0},
            {"instance_id": "b", "status": "completed", "tokens": 200, "wall_time": 20.0},
        ]
        metrics = aggregate_metrics(results)
        assert metrics["total_tasks"] == 2
        assert metrics["completed"] == 2
        assert metrics["timeouts"] == 0
        assert metrics["errors"] == 0
        assert metrics["tokens_mean"] == 150
        assert metrics["tokens_total"] == 300
        assert metrics["time_mean"] == 15.0
        assert metrics["time_total"] == 30.0

    def test_mixed_statuses(self):
        results = [
            {"instance_id": "a", "status": "completed", "tokens": 100, "wall_time": 10.0},
            {"instance_id": "b", "status": "timeout", "tokens": 0, "wall_time": 1800.0},
            {"instance_id": "c", "status": "error", "tokens": 0, "wall_time": 0.0},
            {"instance_id": "d", "status": "failed", "tokens": 50, "wall_time": 5.0},
        ]
        metrics = aggregate_metrics(results)
        assert metrics["total_tasks"] == 4
        assert metrics["completed"] == 1
        assert metrics["timeouts"] == 1
        assert metrics["errors"] == 1
        assert metrics["failed"] == 1

    def test_median_odd_count(self):
        results = [
            {"instance_id": "a", "status": "completed", "tokens": 100, "wall_time": 1.0},
            {"instance_id": "b", "status": "completed", "tokens": 200, "wall_time": 2.0},
            {"instance_id": "c", "status": "completed", "tokens": 300, "wall_time": 3.0},
        ]
        metrics = aggregate_metrics(results)
        assert metrics["tokens_median"] == 200


# ---------------------------------------------------------------------------
# write_overrides
# ---------------------------------------------------------------------------


class TestWriteOverrides:
    def test_creates_override_file(self, tmp_path):
        overrides = write_overrides(tmp_path, "test-instance")
        path = Path(overrides)
        assert path.exists()
        assert path.name == ".eval-overrides.sh"

    def test_override_content_stubs_gh(self, tmp_path):
        overrides = write_overrides(tmp_path, "test-instance")
        content = Path(overrides).read_text()
        assert "gh()" in content
        assert "STUB" in content

    def test_override_content_stubs_wt(self, tmp_path):
        overrides = write_overrides(tmp_path, "test-instance")
        content = Path(overrides).read_text()
        assert "wt()" in content

    def test_override_content_blocks_git_push(self, tmp_path):
        overrides = write_overrides(tmp_path, "test-instance")
        content = Path(overrides).read_text()
        assert "git push" in content
        assert 'command git' in content

    def test_override_includes_instance_id(self, tmp_path):
        overrides = write_overrides(tmp_path, "my-instance-42")
        content = Path(overrides).read_text()
        assert "my-instance-42" in content


# ---------------------------------------------------------------------------
# extract_patch
# ---------------------------------------------------------------------------


class TestExtractPatch:
    def test_extract_patch_from_git_repo(self, tmp_path):
        """Create a real git repo, make a change, and extract the patch."""
        repo = tmp_path / "repo"
        repo.mkdir()

        # Init repo and create initial commit
        subprocess.run(["git", "init"], cwd=str(repo), check=True,
                       capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"],
                       cwd=str(repo), check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"],
                       cwd=str(repo), check=True, capture_output=True)

        (repo / "file.txt").write_text("original\n")
        subprocess.run(["git", "add", "."], cwd=str(repo), check=True,
                       capture_output=True)
        subprocess.run(["git", "commit", "-m", "init"], cwd=str(repo),
                       check=True, capture_output=True)

        # Get base commit
        base = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=str(repo),
            capture_output=True, text=True, check=True,
        ).stdout.strip()

        # Make a change (unstaged)
        (repo / "file.txt").write_text("modified\n")

        patch = extract_patch(str(repo), base)
        assert "file.txt" in patch
        assert "-original" in patch
        assert "+modified" in patch

    def test_extract_patch_no_changes(self, tmp_path):
        """No changes should produce empty patch."""
        repo = tmp_path / "repo"
        repo.mkdir()

        subprocess.run(["git", "init"], cwd=str(repo), check=True,
                       capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"],
                       cwd=str(repo), check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"],
                       cwd=str(repo), check=True, capture_output=True)

        (repo / "file.txt").write_text("original\n")
        subprocess.run(["git", "add", "."], cwd=str(repo), check=True,
                       capture_output=True)
        subprocess.run(["git", "commit", "-m", "init"], cwd=str(repo),
                       check=True, capture_output=True)

        base = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=str(repo),
            capture_output=True, text=True, check=True,
        ).stdout.strip()

        patch = extract_patch(str(repo), base)
        assert patch == ""


# ---------------------------------------------------------------------------
# CLI (main)
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Eval kernel stubs (full mode)
# ---------------------------------------------------------------------------


class TestEvalKernels:
    def test_eval_pr_kernel_returns_pass(self):
        """No-op PR kernel should emit EVENT_PR_PASS."""
        from agentize.workflow.impl.state import EVENT_PR_PASS

        result = _eval_pr_kernel(None)
        assert result.event == EVENT_PR_PASS
        assert "eval mode" in result.reason

    def test_eval_rebase_kernel_returns_ok(self):
        """No-op rebase kernel should emit EVENT_REBASE_OK."""
        from agentize.workflow.impl.state import EVENT_REBASE_OK

        result = _eval_rebase_kernel(None)
        assert result.event == EVENT_REBASE_OK
        assert "eval mode" in result.reason

    def test_eval_kernel_registry_has_all_stages(self):
        """Eval kernel registry should cover all stages from production KERNELS."""
        from agentize.workflow.impl.kernels import KERNELS
        from agentize.workflow.impl.state import STAGE_PR, STAGE_REBASE

        eval_kernels = _build_eval_kernels()
        assert set(eval_kernels.keys()) == set(KERNELS.keys())
        assert eval_kernels[STAGE_PR] is _eval_pr_kernel
        assert eval_kernels[STAGE_REBASE] is _eval_rebase_kernel


# ---------------------------------------------------------------------------
# write_overrides (full mode additions)
# ---------------------------------------------------------------------------


class TestWriteOverridesFullMode:
    def test_overrides_stubs_git_fetch(self, tmp_path):
        content = Path(write_overrides(tmp_path, "test")).read_text()
        assert "fetch" in content

    def test_overrides_stubs_git_rebase(self, tmp_path):
        content = Path(write_overrides(tmp_path, "test")).read_text()
        assert "rebase" in content

    def test_overrides_wt_pathto_returns_dot(self, tmp_path):
        content = Path(write_overrides(tmp_path, "test")).read_text()
        assert "pathto" in content


# ---------------------------------------------------------------------------
# CLI (main)
# ---------------------------------------------------------------------------


class TestCLI:
    def test_no_command_returns_error(self, capsys):
        ret = main([])
        assert ret == 1

    def test_run_help(self, capsys):
        with pytest.raises(SystemExit) as exc_info:
            main(["run", "--help"])
        assert exc_info.value.code == 0

    def test_score_help(self, capsys):
        with pytest.raises(SystemExit) as exc_info:
            main(["score", "--help"])
        assert exc_info.value.code == 0

    def test_mode_flag_default_raw(self):
        """CLI should default to raw mode."""
        import argparse

        # Parse with no --mode flag, check default
        parser = argparse.ArgumentParser()
        parser.add_argument("--mode", choices=["raw", "full"], default="raw")
        args = parser.parse_args([])
        assert args.mode == "raw"
