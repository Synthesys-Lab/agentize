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
    _list_jsonl_files,
    _parse_backend_spec,
    _planner_backends,
    _sum_jsonl_usage,
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

    def test_backend_overrides_forwarded(self, tmp_path, monkeypatch):
        """run_full_impl should forward planner/impl backend overrides."""
        from agentize.eval import eval_harness

        captured: dict[str, str | None] = {}

        def _fake_body(*args, **kwargs):
            captured["planner_backend"] = kwargs.get("planner_backend")
            captured["impl_backend"] = kwargs.get("impl_backend")
            return "completed"

        monkeypatch.setattr(eval_harness, "_run_full_impl_body", _fake_body)
        monkeypatch.setattr(eval_harness, "_list_jsonl_files", lambda: set())

        overrides = write_overrides(tmp_path, "backend-test")
        result = run_full_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="backend-test",
            problem_statement="test",
            timeout=1,
            planner_backend="claude:opus",
            impl_backend="codex:gpt-5.2-codex",
        )

        assert result["status"] == "completed"
        assert captured["planner_backend"] == "claude:opus"
        assert captured["impl_backend"] == "codex:gpt-5.2-codex"


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


class TestBackendParsing:
    def test_parse_backend_spec(self):
        assert _parse_backend_spec("claude:opus") == ("claude", "opus")

    def test_parse_backend_spec_rejects_invalid(self):
        with pytest.raises(ValueError):
            _parse_backend_spec("claude-opus")

    def test_planner_backends_applies_one_override_to_all_stages(self):
        backends = _planner_backends("claude:opus")
        assert backends == {
            "understander": ("claude", "opus"),
            "bold": ("claude", "opus"),
            "critique": ("claude", "opus"),
            "reducer": ("claude", "opus"),
            "consensus": ("claude", "opus"),
        }


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

    def test_extracts_cache_tokens(self):
        """Should extract cache_read and cache_write token fields."""
        stdout = json.dumps({
            "model": "claude-sonnet-4-20260514",
            "usage": {
                "input_tokens": 1000,
                "output_tokens": 500,
                "cache_read_input_tokens": 800,
                "cache_creation_input_tokens": 100,
            },
        })
        usage = _parse_claude_usage(stdout, "sonnet")
        assert usage["cache_read_tokens"] == 800
        assert usage["cache_write_tokens"] == 100

    def test_cache_tokens_default_zero(self):
        """Cache tokens should default to 0 when not present."""
        stdout = json.dumps({
            "model": "claude-sonnet-4-20260514",
            "usage": {"input_tokens": 1000, "output_tokens": 500},
        })
        usage = _parse_claude_usage(stdout, "sonnet")
        assert usage["cache_read_tokens"] == 0
        assert usage["cache_write_tokens"] == 0

    def test_cache_aware_cost(self):
        """Cost should use cache tiers when cache tokens are present."""
        stdout_no_cache = json.dumps({
            "model": "claude-sonnet-4-20260514",
            "usage": {"input_tokens": 1000, "output_tokens": 500},
        })
        stdout_with_cache = json.dumps({
            "model": "claude-sonnet-4-20260514",
            "usage": {
                "input_tokens": 1000,
                "output_tokens": 500,
                "cache_read_input_tokens": 900,
                "cache_creation_input_tokens": 0,
            },
        })
        cost_no_cache = _parse_claude_usage(stdout_no_cache, "sonnet")["cost_usd"]
        cost_with_cache = _parse_claude_usage(stdout_with_cache, "sonnet")["cost_usd"]
        # With 900/1000 tokens as cache reads (10x cheaper), cost should be lower
        assert cost_with_cache < cost_no_cache


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

    def test_cache_read_reduces_cost(self):
        """Cache reads at 0.1x should be much cheaper than base input."""
        # 1M input, 0 output, all cache reads — sonnet cache_read = $0.30/M
        cost_cached = _compute_cost(1_000_000, 0, "sonnet",
                                    cache_read=1_000_000, cache_write=0)
        # All tokens are cache reads → non_cache = 0, cost = cache_read rate only
        assert cost_cached == pytest.approx(0.30)

    def test_cache_write_cost(self):
        """Cache writes at 1.25x should cost more than base input."""
        # 1M input, 0 output, all cache writes — sonnet cache_write = $3.75/M
        cost = _compute_cost(1_000_000, 0, "sonnet",
                             cache_read=0, cache_write=1_000_000)
        assert cost == pytest.approx(3.75)

    def test_mixed_cache_tiers(self):
        """Mixed cache tiers should split cost correctly."""
        # 1M total input: 500K cache_read, 200K cache_write, 300K base
        # Sonnet: base=$3/M, cache_read=$0.30/M, cache_write=$3.75/M, output=$15/M
        cost = _compute_cost(1_000_000, 100_000, "sonnet",
                             cache_read=500_000, cache_write=200_000)
        expected = (
            300_000 * 3.0 / 1_000_000      # base input
            + 100_000 * 15.0 / 1_000_000   # output
            + 500_000 * 0.30 / 1_000_000   # cache_read
            + 200_000 * 3.75 / 1_000_000   # cache_write
        )
        assert cost == pytest.approx(expected)

    def test_no_cache_params_backward_compat(self):
        """Without cache params, should behave like before (all input at base rate)."""
        cost = _compute_cost(1_000_000, 0, "sonnet")
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
        assert result["cost_note"] == "cost estimated from new JSONL session files"

    def test_jsonl_cost_tracking_on_timeout(self, tmp_path, monkeypatch):
        """JSONL-based cost tracking should capture partial costs on timeout."""
        def _slow_run(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="claude", timeout=1)

        monkeypatch.setattr(subprocess, "run", _slow_run)

        # Mock JSONL tracking to return known values
        call_count = [0]

        def _mock_list_jsonl():
            call_count[0] += 1
            if call_count[0] == 1:
                return set()  # before
            return {"/tmp/fake-session.jsonl"}  # after

        mock_usage = {
            "input_tokens": 100, "output_tokens": 200,
            "cache_read": 10, "cache_write": 20,
            "tokens": 300, "cost_usd": 1.50,
        }

        monkeypatch.setattr(
            "agentize.eval.eval_harness._list_jsonl_files", _mock_list_jsonl
        )
        monkeypatch.setattr(
            "agentize.eval.eval_harness._sum_jsonl_usage",
            lambda paths: mock_usage,
        )

        overrides = write_overrides(tmp_path, "nlcmd-jsonl")
        result = run_nlcmd_impl(
            wt_path=str(tmp_path),
            overrides_path=overrides,
            instance_id="nlcmd-jsonl",
            problem_statement="test",
            timeout=2,
        )
        assert result["input_tokens"] == 100
        assert result["output_tokens"] == 200
        assert result["cache_read_tokens"] == 10
        assert result["cache_write_tokens"] == 20
        assert result["tokens"] == 300
        assert result["cost_usd"] == 1.50


# ---------------------------------------------------------------------------
# JSONL deduplication tests
# ---------------------------------------------------------------------------


class TestSumJsonlUsageDedup:
    def test_dedup_by_message_id(self, tmp_path):
        """Duplicate entries with same message.id should be counted once."""
        jsonl = tmp_path / "session.jsonl"
        lines = [
            json.dumps({"type": "assistant", "message": {
                "id": "msg_001", "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 100, "output_tokens": 50,
                          "cache_read_input_tokens": 80,
                          "cache_creation_input_tokens": 0}}}),
            # Duplicate — same message.id, different content block
            json.dumps({"type": "assistant", "message": {
                "id": "msg_001", "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 100, "output_tokens": 50,
                          "cache_read_input_tokens": 80,
                          "cache_creation_input_tokens": 0}}}),
        ]
        jsonl.write_text("\n".join(lines) + "\n")

        result = _sum_jsonl_usage([str(jsonl)])
        # Should count only once despite two lines
        assert result["input_tokens"] == 100
        assert result["output_tokens"] == 50
        assert result["cache_read"] == 80

    def test_different_message_ids_both_counted(self, tmp_path):
        """Entries with different message.id should both be counted."""
        jsonl = tmp_path / "session.jsonl"
        lines = [
            json.dumps({"type": "assistant", "message": {
                "id": "msg_001", "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 100, "output_tokens": 50}}}),
            json.dumps({"type": "assistant", "message": {
                "id": "msg_002", "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 200, "output_tokens": 75}}}),
        ]
        jsonl.write_text("\n".join(lines) + "\n")

        result = _sum_jsonl_usage([str(jsonl)])
        assert result["input_tokens"] == 300
        assert result["output_tokens"] == 125

    def test_no_message_id_still_counted(self, tmp_path):
        """Entries without message.id should still be counted (no dedup)."""
        jsonl = tmp_path / "session.jsonl"
        lines = [
            json.dumps({"type": "assistant", "message": {
                "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 100, "output_tokens": 50}}}),
            json.dumps({"type": "assistant", "message": {
                "model": "claude-sonnet-4-20260514",
                "usage": {"input_tokens": 200, "output_tokens": 75}}}),
        ]
        jsonl.write_text("\n".join(lines) + "\n")

        result = _sum_jsonl_usage([str(jsonl)])
        # No message.id → no dedup → both counted
        assert result["input_tokens"] == 300
        assert result["output_tokens"] == 125

    def test_dedup_scoped_per_file(self, tmp_path):
        """Dedup sets should reset between files (same msg ID in different files = counted twice)."""
        jsonl1 = tmp_path / "session1.jsonl"
        jsonl2 = tmp_path / "session2.jsonl"
        line = json.dumps({"type": "assistant", "message": {
            "id": "msg_001", "model": "claude-sonnet-4-20260514",
            "usage": {"input_tokens": 100, "output_tokens": 50}}})
        jsonl1.write_text(line + "\n")
        jsonl2.write_text(line + "\n")

        result = _sum_jsonl_usage([str(jsonl1), str(jsonl2)])
        # Same msg ID but different files → counted in each file
        assert result["input_tokens"] == 200
        assert result["output_tokens"] == 100
