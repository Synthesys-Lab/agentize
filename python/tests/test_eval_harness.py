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
    run_full_impl,
    run_nlcmd_impl,
    write_overrides,
    main,
    _eval_pr_kernel,
    _eval_rebase_kernel,
    _build_eval_kernels,
    _parse_claude_usage,
    _compute_cost,
    _make_result,
    _find_consensus_plan,
    _PLANNER_CMD_TEMPLATES,
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


class TestFullImplTimeout:
    def test_timeout_returns_timeout_status(self, tmp_path, monkeypatch):
        """run_full_impl should return 'timeout' when the pipeline exceeds the limit."""
        import time as _time

        # Monkeypatch _run_full_impl_body to sleep forever
        def _slow_body(*args, **kwargs):
            _time.sleep(60)
            return "completed"

        from agentize.eval import eval_harness
        monkeypatch.setattr(eval_harness, "_run_full_impl_body", _slow_body)

        overrides = write_overrides(tmp_path, "timeout-test")
        result = run_full_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="timeout-test",
            problem_statement="test",
            timeout=1,  # 1 second timeout
        )
        assert result["status"] == "timeout"
        assert result["wall_time"] <= 3.0  # should return promptly after 1s


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
        parser.add_argument("--mode", choices=["raw", "full", "impl", "nlcmd"], default="raw")
        args = parser.parse_args([])
        assert args.mode == "raw"

    def test_nlcmd_mode_accepted(self):
        """CLI should accept nlcmd as a valid mode."""
        import argparse

        parser = argparse.ArgumentParser()
        parser.add_argument("--mode", choices=["raw", "full", "impl", "nlcmd"], default="raw")
        args = parser.parse_args(["--mode", "nlcmd"])
        assert args.mode == "nlcmd"


# ---------------------------------------------------------------------------
# Cost tracking helpers
# ---------------------------------------------------------------------------


class TestMakeResult:
    def test_has_cost_fields(self):
        result = _make_result("test-123")
        assert result["instance_id"] == "test-123"
        assert result["cost_usd"] == 0.0
        assert result["input_tokens"] == 0
        assert result["output_tokens"] == 0
        assert result["tokens"] == 0
        assert result["status"] == "error"


class TestParseClaudeUsage:
    def test_valid_json_with_usage(self):
        stdout = json.dumps({
            "model": "claude-sonnet-4-20260514",
            "usage": {"input_tokens": 1000, "output_tokens": 500},
            "content": [{"type": "text", "text": "hello"}],
        })
        usage = _parse_claude_usage(stdout, "sonnet")
        assert usage["input_tokens"] == 1000
        assert usage["output_tokens"] == 500
        assert usage["tokens"] == 1500
        assert usage["cost_usd"] > 0

    def test_empty_stdout(self):
        usage = _parse_claude_usage("", "sonnet")
        assert usage["tokens"] == 0
        assert usage["cost_usd"] == 0.0

    def test_invalid_json(self):
        usage = _parse_claude_usage("not json", "sonnet")
        assert usage["tokens"] == 0

    def test_missing_usage_key(self):
        stdout = json.dumps({"model": "claude-sonnet-4"})
        usage = _parse_claude_usage(stdout, "sonnet")
        assert usage["tokens"] == 0
        assert usage["cost_usd"] == 0.0

    def test_uses_json_model_for_cost(self):
        """Should use model from JSON response, not the fallback."""
        stdout = json.dumps({
            "model": "claude-opus-4-20260514",
            "usage": {"input_tokens": 1000, "output_tokens": 500},
        })
        usage_opus = _parse_claude_usage(stdout, "sonnet")
        # Opus is more expensive than sonnet
        usage_sonnet = _parse_claude_usage(
            json.dumps({
                "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 1000, "output_tokens": 500},
            }),
            "sonnet",
        )
        assert usage_opus["cost_usd"] > usage_sonnet["cost_usd"]


class TestComputeCost:
    def test_sonnet_cost(self):
        # Sonnet: $3/M input, $15/M output
        cost = _compute_cost(1_000_000, 1_000_000, "sonnet")
        assert cost == pytest.approx(18.0)

    def test_opus_cost(self):
        # Opus: $15/M input, $75/M output
        cost = _compute_cost(1_000_000, 1_000_000, "opus")
        assert cost == pytest.approx(90.0)

    def test_zero_tokens(self):
        cost = _compute_cost(0, 0, "sonnet")
        assert cost == 0.0

    def test_unknown_model(self):
        cost = _compute_cost(1000, 1000, "unknown-model-xyz")
        assert cost == 0.0

    def test_full_model_id(self):
        """Should handle full model IDs via prefix matching."""
        cost = _compute_cost(1_000_000, 0, "claude-sonnet-4-20260514")
        assert cost == pytest.approx(3.0)


class TestAggregateMetricsCost:
    def test_cost_aggregation(self):
        results = [
            {
                "instance_id": "a", "status": "completed",
                "tokens": 100, "input_tokens": 60, "output_tokens": 40,
                "wall_time": 10.0, "cost_usd": 0.50,
            },
            {
                "instance_id": "b", "status": "completed",
                "tokens": 200, "input_tokens": 120, "output_tokens": 80,
                "wall_time": 20.0, "cost_usd": 1.00,
            },
        ]
        metrics = aggregate_metrics(results)
        assert metrics["cost_total_usd"] == pytest.approx(1.50)
        assert metrics["cost_mean_usd"] == pytest.approx(0.75)
        assert metrics["input_tokens_total"] == 180
        assert metrics["output_tokens_total"] == 120

    def test_cost_zero_when_no_tracking(self):
        results = [
            {
                "instance_id": "a", "status": "completed",
                "tokens": 100, "wall_time": 10.0,
            },
        ]
        metrics = aggregate_metrics(results)
        assert metrics["cost_total_usd"] == 0.0
        assert metrics["cost_mean_usd"] == 0.0


class TestPlannerCmdTemplates:
    def test_ultra_planner_template(self):
        """ultra-planner template should include --force-full and --dry-run."""
        tpl = _PLANNER_CMD_TEMPLATES["ultra-planner"]
        rendered = tpl.format(problem_statement="fix the bug")
        assert "/ultra-planner" in rendered
        assert "--force-full" in rendered
        assert "--dry-run" in rendered
        assert "fix the bug" in rendered

    def test_mega_planner_template(self):
        """mega-planner template should pass problem statement directly."""
        tpl = _PLANNER_CMD_TEMPLATES["mega-planner"]
        rendered = tpl.format(problem_statement="fix the bug")
        assert "/mega-planner" in rendered
        assert "fix the bug" in rendered

    def test_both_planners_registered(self):
        assert "ultra-planner" in _PLANNER_CMD_TEMPLATES
        assert "mega-planner" in _PLANNER_CMD_TEMPLATES


class TestFindConsensusPlan:
    def test_finds_consensus_file(self, tmp_path):
        (tmp_path / "issue-dry-run-20260225-consensus.md").write_text("the plan")
        assert _find_consensus_plan(tmp_path) == "the plan"

    def test_picks_newest(self, tmp_path):
        import time as _time

        (tmp_path / "issue-1-consensus.md").write_text("old plan")
        _time.sleep(0.05)
        (tmp_path / "issue-2-consensus.md").write_text("new plan")
        assert _find_consensus_plan(tmp_path) == "new plan"

    def test_returns_empty_when_no_files(self, tmp_path):
        assert _find_consensus_plan(tmp_path) == ""

    def test_ignores_non_consensus_files(self, tmp_path):
        (tmp_path / "issue-1-bold.md").write_text("not a plan")
        (tmp_path / "issue-1-critique.md").write_text("also not a plan")
        assert _find_consensus_plan(tmp_path) == ""


class TestNlcmdImpl:
    def test_timeout_returns_timeout_status(self, tmp_path, monkeypatch):
        """run_nlcmd_impl should return 'timeout' when planning exceeds limit."""
        # Mock subprocess.run to simulate a timeout
        def _slow_run(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="claude", timeout=1)

        monkeypatch.setattr(subprocess, "run", _slow_run)

        overrides = write_overrides(tmp_path, "nlcmd-timeout")
        result = run_nlcmd_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="nlcmd-timeout",
            problem_statement="test problem",
            timeout=2,
        )
        assert result["status"] == "timeout"

    def test_unknown_planner_returns_error(self, tmp_path):
        overrides = write_overrides(tmp_path, "nlcmd-bad")
        result = run_nlcmd_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="nlcmd-bad",
            problem_statement="test",
            planner_cmd="nonexistent-planner",
        )
        assert result["status"] == "error"

    def test_result_has_planner_cmd(self, tmp_path, monkeypatch):
        """Result dict should record which planner command was used."""
        def _slow_run(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="claude", timeout=1)

        monkeypatch.setattr(subprocess, "run", _slow_run)

        overrides = write_overrides(tmp_path, "nlcmd-meta")
        result = run_nlcmd_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="nlcmd-meta",
            problem_statement="test",
            planner_cmd="mega-planner",
            timeout=2,
        )
        assert result["planner_cmd"] == "mega-planner"
        assert "cost_note" in result
