"""Tests for .claude-plugin/lib/workflow.py module.

Replaces tests/cli/test-workflow-module.sh with pytest equivalents.
"""

import os
import inspect
from pathlib import Path
from unittest.mock import patch

import pytest

from lib.workflow import (
    ULTRA_PLANNER,
    ISSUE_TO_IMPL,
    PLAN_TO_ISSUE,
    SETUP_VIEWBOARD,
    SYNC_MASTER,
    detect_workflow,
    extract_issue_no,
    extract_pr_no,
    has_continuation_prompt,
    get_continuation_prompt,
    _get_supervisor_provider,
    _get_supervisor_model,
    _get_supervisor_flags,
    _ask_supervisor_for_guidance,
    _run_acw,
)
from lib.session_utils import get_agentize_home


# ============================================================
# Test detect_workflow()
# ============================================================

class TestDetectWorkflow:
    """Tests for detect_workflow function."""

    def test_ultra_planner(self):
        """detect_workflow('/ultra-planner') → ultra-planner"""
        assert detect_workflow('/ultra-planner') == 'ultra-planner'

    def test_ultra_planner_with_args(self):
        """detect_workflow('/ultra-planner --refine 42') → ultra-planner"""
        assert detect_workflow('/ultra-planner --refine 42') == 'ultra-planner'

    def test_issue_to_impl(self):
        """detect_workflow('/issue-to-impl 42') → issue-to-impl"""
        assert detect_workflow('/issue-to-impl 42') == 'issue-to-impl'

    def test_plan_to_issue(self):
        """detect_workflow('/plan-to-issue') → plan-to-issue"""
        assert detect_workflow('/plan-to-issue') == 'plan-to-issue'

    def test_setup_viewboard(self):
        """detect_workflow('/setup-viewboard') → setup-viewboard"""
        assert detect_workflow('/setup-viewboard') == 'setup-viewboard'

    def test_sync_master(self):
        """detect_workflow('/sync-master 123') → sync-master"""
        assert detect_workflow('/sync-master 123') == 'sync-master'

    def test_non_workflow_greeting(self):
        """detect_workflow('Hello, how are you?') → None"""
        assert detect_workflow('Hello, how are you?') is None

    def test_unknown_command(self):
        """detect_workflow('/unknown-command') → None"""
        assert detect_workflow('/unknown-command') is None


# ============================================================
# Test extract_issue_no()
# ============================================================

class TestExtractIssueNo:
    """Tests for extract_issue_no function."""

    def test_issue_to_impl_number(self):
        """extract_issue_no('/issue-to-impl 42') → 42"""
        assert extract_issue_no('/issue-to-impl 42') == 42

    def test_ultra_planner_refine(self):
        """extract_issue_no('/ultra-planner --refine 123') → 123"""
        assert extract_issue_no('/ultra-planner --refine 123') == 123

    def test_ultra_planner_from_issue(self):
        """extract_issue_no('/ultra-planner --from-issue 456') → 456"""
        assert extract_issue_no('/ultra-planner --from-issue 456') == 456

    def test_ultra_planner_no_issue(self):
        """extract_issue_no('/ultra-planner new feature') → None"""
        assert extract_issue_no('/ultra-planner new feature') is None

    def test_plan_to_issue_no_number(self):
        """extract_issue_no('/plan-to-issue') → None"""
        assert extract_issue_no('/plan-to-issue') is None

    def test_issue_to_impl_with_dry_run_after(self):
        """extract_issue_no('/issue-to-impl 42 --dry-run') → 42"""
        assert extract_issue_no('/issue-to-impl 42 --dry-run') == 42

    def test_issue_to_impl_with_dry_run_before(self):
        """extract_issue_no('/issue-to-impl --dry-run 42') → 42"""
        assert extract_issue_no('/issue-to-impl --dry-run 42') == 42


# ============================================================
# Test extract_pr_no()
# ============================================================

class TestExtractPrNo:
    """Tests for extract_pr_no function."""

    def test_sync_master_with_pr(self):
        """extract_pr_no('/sync-master 789') → 789"""
        assert extract_pr_no('/sync-master 789') == 789

    def test_sync_master_without_pr(self):
        """extract_pr_no('/sync-master') → None"""
        assert extract_pr_no('/sync-master') is None


# ============================================================
# Test has_continuation_prompt()
# ============================================================

class TestHasContinuationPrompt:
    """Tests for has_continuation_prompt function."""

    def test_ultra_planner(self):
        """has_continuation_prompt('ultra-planner') → True"""
        assert has_continuation_prompt('ultra-planner') is True

    def test_issue_to_impl(self):
        """has_continuation_prompt('issue-to-impl') → True"""
        assert has_continuation_prompt('issue-to-impl') is True

    def test_plan_to_issue(self):
        """has_continuation_prompt('plan-to-issue') → True"""
        assert has_continuation_prompt('plan-to-issue') is True

    def test_setup_viewboard(self):
        """has_continuation_prompt('setup-viewboard') → True"""
        assert has_continuation_prompt('setup-viewboard') is True

    def test_sync_master(self):
        """has_continuation_prompt('sync-master') → True"""
        assert has_continuation_prompt('sync-master') is True

    def test_unknown_workflow(self):
        """has_continuation_prompt('unknown-workflow') → False"""
        assert has_continuation_prompt('unknown-workflow') is False


# ============================================================
# Test get_continuation_prompt()
# ============================================================

class TestGetContinuationPrompt:
    """Tests for get_continuation_prompt function."""

    def test_contains_session_id(self, monkeypatch):
        """get_continuation_prompt() returns formatted string with session_id"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
        assert 'test-session-123' in prompt

    def test_contains_count(self, monkeypatch):
        """get_continuation_prompt() returns formatted string with count"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
        assert '3/10' in prompt

    def test_contains_fname(self, monkeypatch):
        """get_continuation_prompt() returns formatted string with fname"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
        assert '/tmp/test.json' in prompt

    def test_issue_to_impl_contains_milestone(self, monkeypatch):
        """get_continuation_prompt() for issue-to-impl includes milestone text"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10)
        assert 'milestone' in prompt.lower()

    def test_setup_viewboard_contains_correct_text(self, monkeypatch):
        """get_continuation_prompt() for setup-viewboard includes correct text"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('setup-viewboard', 'test-session', '/tmp/test.json', 1, 10)
        assert 'Projects v2 board' in prompt

    def test_unknown_workflow_returns_empty(self, monkeypatch):
        """get_continuation_prompt() for unknown workflow returns empty string"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('unknown-workflow', 'test-session', '/tmp/test.json', 1, 10)
        assert prompt == ''


# ============================================================
# Test plan context in continuation prompt
# ============================================================

class TestContinuationPromptPlanContext:
    """Tests for plan context handling in get_continuation_prompt."""

    def test_issue_to_impl_includes_plan_path(self, monkeypatch):
        """get_continuation_prompt() for issue-to-impl includes plan_path when provided"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt(
            'issue-to-impl', 'test-session', '/tmp/test.json', 1, 10,
            plan_path='/tmp/plan-of-issue-42.md'
        )
        assert '/tmp/plan-of-issue-42.md' in prompt

    def test_issue_to_impl_includes_plan_excerpt(self, monkeypatch):
        """get_continuation_prompt() for issue-to-impl includes plan_excerpt when provided"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt(
            'issue-to-impl', 'test-session', '/tmp/test.json', 1, 10,
            plan_path='/tmp/plan.md', plan_excerpt='Step 1: Add feature X'
        )
        assert 'Step 1: Add feature X' in prompt

    def test_issue_to_impl_works_without_plan_context(self, monkeypatch):
        """get_continuation_prompt() for issue-to-impl works without plan context"""
        monkeypatch.setenv('HANDSOFF_SUPERVISOR', 'none')
        prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10)
        # Should still have the base prompt without plan context
        assert 'milestone' in prompt.lower()
        assert 'Plan file:' not in prompt


# ============================================================
# Test workflow constants
# ============================================================

class TestWorkflowConstants:
    """Tests for workflow name constants."""

    def test_ultra_planner_constant(self):
        """ULTRA_PLANNER constant equals 'ultra-planner'"""
        assert ULTRA_PLANNER == 'ultra-planner'

    def test_issue_to_impl_constant(self):
        """ISSUE_TO_IMPL constant equals 'issue-to-impl'"""
        assert ISSUE_TO_IMPL == 'issue-to-impl'

    def test_plan_to_issue_constant(self):
        """PLAN_TO_ISSUE constant equals 'plan-to-issue'"""
        assert PLAN_TO_ISSUE == 'plan-to-issue'

    def test_setup_viewboard_constant(self):
        """SETUP_VIEWBOARD constant equals 'setup-viewboard'"""
        assert SETUP_VIEWBOARD == 'setup-viewboard'

    def test_sync_master_constant(self):
        """SYNC_MASTER constant equals 'sync-master'"""
        assert SYNC_MASTER == 'sync-master'


# ============================================================
# Test HANDSOFF_SUPERVISOR provider enum behavior (YAML-only config)
# ============================================================

class TestSupervisorProvider:
    """Tests for supervisor provider configuration (YAML-only)."""

    def test_none_disables_supervisor(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.provider=none disables supervisor (returns None)"""
        config_content = """
handsoff:
  supervisor:
    provider: none
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        result = _ask_supervisor_for_guidance(
            'test-session', '/tmp/test.json', 'ultra-planner', 1, 10, '/tmp/dummy-transcript.jsonl'
        )
        assert result is None

    def test_claude_enables_supervisor(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.provider=claude enables supervisor path"""
        config_content = """
handsoff:
  supervisor:
    provider: claude
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        provider = _get_supervisor_provider()
        assert provider == 'claude'

    def test_codex_sets_provider(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.provider=codex sets codex as provider"""
        config_content = """
handsoff:
  supervisor:
    provider: codex
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        provider = _get_supervisor_provider()
        assert provider == 'codex'

    def test_model_reads_correctly(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.model reads model correctly from YAML"""
        config_content = """
handsoff:
  supervisor:
    provider: claude
    model: opus
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        model = _get_supervisor_model('claude')
        assert model == 'opus'

    def test_model_uses_default(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.model uses provider default when not set in YAML"""
        config_content = """
handsoff:
  supervisor:
    provider: claude
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        model = _get_supervisor_model('claude')
        assert model == 'opus'

    def test_flags_reads_correctly(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.flags is read correctly from YAML"""
        config_content = """
handsoff:
  supervisor:
    provider: claude
    flags: "--timeout 1800"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        flags = _get_supervisor_flags()
        assert flags == '--timeout 1800'

    def test_flags_defaults_to_empty(self, tmp_path, monkeypatch, clear_local_config_cache):
        """handsoff.supervisor.flags defaults to empty string when not set in YAML"""
        config_content = """
handsoff:
  supervisor:
    provider: claude
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)
        monkeypatch.chdir(tmp_path)

        flags = _get_supervisor_flags()
        assert flags == ''


# ============================================================
# Test get_agentize_home() (session_utils)
# ============================================================

class TestGetAgentizeHome:
    """Tests for get_agentize_home function."""

    def test_reads_from_env_var(self, monkeypatch):
        """get_agentize_home() reads from AGENTIZE_HOME env var"""
        monkeypatch.setenv('AGENTIZE_HOME', '/custom/path')
        home = get_agentize_home()
        assert home == '/custom/path'

    def test_derives_valid_repo_root(self, monkeypatch):
        """get_agentize_home() derives from session_utils.py location when env var not set"""
        monkeypatch.delenv('AGENTIZE_HOME', raising=False)
        home = get_agentize_home()
        # Should derive to repo root where Makefile exists
        makefile = os.path.join(home, 'Makefile')
        assert os.path.isfile(makefile), f"Expected Makefile at {makefile}"

    def test_derives_correct_repo_structure(self, monkeypatch):
        """get_agentize_home() returns correct repo root structure"""
        monkeypatch.delenv('AGENTIZE_HOME', raising=False)
        home = get_agentize_home()
        # Verify expected files exist
        acw_sh = os.path.join(home, 'src', 'cli', 'acw.sh')
        assert os.path.isfile(acw_sh), f"Expected acw.sh at {acw_sh}"


# ============================================================
# Test _run_acw() helper
# ============================================================

class TestRunAcw:
    """Tests for _run_acw helper function."""

    def test_function_signature(self):
        """_run_acw() has correct function signature"""
        sig = inspect.signature(_run_acw)
        params = list(sig.parameters.keys())
        expected = ['provider', 'model', 'input_file', 'output_file', 'extra_flags', 'timeout']
        assert params == expected

    def test_sources_acw_correctly(self, tmp_path, monkeypatch):
        """_run_acw() sources acw.sh correctly (mock test)"""
        # Create mock AGENTIZE_HOME structure
        mock_home = tmp_path / "mock_agentize"
        cli_dir = mock_home / "src" / "cli"
        cli_dir.mkdir(parents=True)

        # Create mock acw.sh that writes to output file
        acw_sh = cli_dir / "acw.sh"
        acw_sh.write_text('''acw() {
    # Real acw writes to 4th argument (output_file)
    local output_file="$4"
    echo "ACW_CALLED: provider=$1 model=$2 input=$3 output=$4" > "$output_file"
}
''')

        # Create input file
        input_file = tmp_path / "input.txt"
        input_file.write_text("test input")
        output_file = tmp_path / "output.txt"

        monkeypatch.setenv('AGENTIZE_HOME', str(mock_home))

        result = _run_acw('claude', 'opus', str(input_file), str(output_file), [])
        assert result.returncode == 0

        # Verify output file contains expected content
        assert output_file.exists()
        output_content = output_file.read_text()
        assert 'ACW_CALLED' in output_content
