"""Tests for .claude-plugin/lib/permission/rules.py YAML rule loading and merging."""

import pytest
from pathlib import Path

# Add .claude-plugin to path for imports
import sys
project_root = Path(__file__).resolve().parents[2]
plugin_dir = project_root / ".claude-plugin"
sys.path.insert(0, str(plugin_dir))

from lib.permission.rules import (
    match_rule,
    PERMISSION_RULES,
    _find_config_paths,
    _extract_yaml_rules,
    _get_merged_rules,
    clear_yaml_cache,
)


@pytest.fixture(autouse=True)
def clear_cache():
    """Clear YAML rules cache before each test."""
    clear_yaml_cache()
    yield
    clear_yaml_cache()


class TestHardcodedRules:
    """Tests for hardcoded rules in PERMISSION_RULES."""

    def test_hardcoded_deny_rules_exist(self):
        """Test that hardcoded deny rules are defined."""
        deny_rules = PERMISSION_RULES.get('deny', [])
        assert len(deny_rules) > 0

        # Check for known deny rules
        deny_patterns = [pattern for _, pattern in deny_rules]
        assert any('cd' in p for p in deny_patterns)
        assert any('rm -rf' in p for p in deny_patterns)

    def test_hardcoded_allow_rules_exist(self):
        """Test that hardcoded allow rules are defined."""
        allow_rules = PERMISSION_RULES.get('allow', [])
        assert len(allow_rules) > 0

    def test_match_rule_returns_hardcoded_deny(self):
        """Test match_rule returns deny for hardcoded deny patterns."""
        result = match_rule('Bash', 'cd /tmp')
        assert result is not None
        assert result[0] == 'deny'

    def test_match_rule_returns_hardcoded_allow(self):
        """Test match_rule returns allow for hardcoded allow patterns."""
        result = match_rule('Bash', 'git status')
        assert result is not None
        assert result[0] == 'allow'


class TestFindConfigPaths:
    """Tests for _find_config_paths function."""

    def test_find_config_paths_returns_none_when_not_found(self, tmp_path):
        """Test _find_config_paths returns None when no config files exist."""
        project_path, local_path = _find_config_paths(tmp_path)
        assert project_path is None
        assert local_path is None

    def test_find_config_paths_finds_project_config(self, tmp_path):
        """Test _find_config_paths finds .agentize.yaml."""
        (tmp_path / ".agentize.yaml").write_text("project:\n  name: test")

        project_path, local_path = _find_config_paths(tmp_path)
        assert project_path is not None
        assert local_path is None

    def test_find_config_paths_finds_local_config(self, tmp_path):
        """Test _find_config_paths finds .agentize.local.yaml."""
        (tmp_path / ".agentize.local.yaml").write_text("handsoff:\n  enabled: true")

        project_path, local_path = _find_config_paths(tmp_path)
        assert project_path is None
        assert local_path is not None

    def test_find_config_paths_finds_both(self, tmp_path):
        """Test _find_config_paths finds both config files."""
        (tmp_path / ".agentize.yaml").write_text("project:\n  name: test")
        (tmp_path / ".agentize.local.yaml").write_text("handsoff:\n  enabled: true")

        project_path, local_path = _find_config_paths(tmp_path)
        assert project_path is not None
        assert local_path is not None


class TestExtractYamlRules:
    """Tests for _extract_yaml_rules function."""

    def test_extract_yaml_rules_empty_config(self):
        """Test _extract_yaml_rules returns empty dict for config without permissions."""
        config = {"project": {"name": "test"}}
        rules = _extract_yaml_rules(config, "project")

        assert rules.get("allow", []) == []
        assert rules.get("deny", []) == []

    def test_extract_yaml_rules_string_items(self):
        """Test _extract_yaml_rules normalizes string items."""
        config = {
            "permissions": {
                "allow": ["^npm run build", "^make test"],
                "deny": ["^rm -rf"]
            }
        }
        rules = _extract_yaml_rules(config, "project")

        allow = rules.get("allow", [])
        assert len(allow) == 2
        assert ("Bash", "^npm run build", "project") in allow
        assert ("Bash", "^make test", "project") in allow

        deny = rules.get("deny", [])
        assert len(deny) == 1
        assert ("Bash", "^rm -rf", "project") in deny

    def test_extract_yaml_rules_dict_items(self):
        """Test _extract_yaml_rules normalizes dict items with pattern and tool."""
        config = {
            "permissions": {
                "allow": [
                    {"pattern": "^cat .*\\.md$", "tool": "Read"},
                    {"pattern": "^npm run build"}  # tool defaults to Bash
                ]
            }
        }
        rules = _extract_yaml_rules(config, "local")

        allow = rules.get("allow", [])
        assert len(allow) == 2
        assert ("Read", "^cat .*\\.md$", "local") in allow
        assert ("Bash", "^npm run build", "local") in allow

    def test_extract_yaml_rules_mixed_items(self):
        """Test _extract_yaml_rules handles mixed string and dict items."""
        config = {
            "permissions": {
                "allow": [
                    "^npm run build",
                    {"pattern": "^cat .*\\.md$", "tool": "Read"}
                ]
            }
        }
        rules = _extract_yaml_rules(config, "local")

        allow = rules.get("allow", [])
        assert len(allow) == 2
        assert ("Bash", "^npm run build", "local") in allow
        assert ("Read", "^cat .*\\.md$", "local") in allow


class TestGetMergedRules:
    """Tests for _get_merged_rules function."""

    def test_get_merged_rules_no_yaml(self, tmp_path, monkeypatch):
        """Test _get_merged_rules returns empty when no YAML files exist."""
        monkeypatch.chdir(tmp_path)

        rules = _get_merged_rules(tmp_path)
        assert rules.get("allow", []) == []
        assert rules.get("deny", []) == []

    def test_get_merged_rules_project_only(self, tmp_path, monkeypatch):
        """Test _get_merged_rules loads project config only."""
        config_content = """
permissions:
  allow:
    - "^npm run build"
"""
        (tmp_path / ".agentize.yaml").write_text(config_content)
        monkeypatch.chdir(tmp_path)

        rules = _get_merged_rules(tmp_path)
        allow = rules.get("allow", [])
        assert len(allow) == 1
        assert ("Bash", "^npm run build", "project") in allow

    def test_get_merged_rules_local_only(self, tmp_path, monkeypatch):
        """Test _get_merged_rules loads local config only."""
        config_content = """
permissions:
  deny:
    - "^npm run deploy"
"""
        (tmp_path / ".agentize.local.yaml").write_text(config_content)
        monkeypatch.chdir(tmp_path)

        rules = _get_merged_rules(tmp_path)
        deny = rules.get("deny", [])
        assert len(deny) == 1
        assert ("Bash", "^npm run deploy", "local") in deny

    def test_get_merged_rules_merges_both(self, tmp_path, monkeypatch):
        """Test _get_merged_rules merges project and local configs."""
        (tmp_path / ".agentize.yaml").write_text("""
permissions:
  allow:
    - "^npm run build"
""")
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  allow:
    - "^npm run test"
  deny:
    - "^npm run deploy"
""")
        monkeypatch.chdir(tmp_path)

        rules = _get_merged_rules(tmp_path)
        allow = rules.get("allow", [])
        deny = rules.get("deny", [])

        # Project rules come first, then local
        assert ("Bash", "^npm run build", "project") in allow
        assert ("Bash", "^npm run test", "local") in allow
        assert ("Bash", "^npm run deploy", "local") in deny


class TestMatchRuleWithYaml:
    """Tests for match_rule with YAML-configured rules."""

    def test_hardcoded_deny_wins_over_yaml_allow(self, tmp_path, monkeypatch):
        """Test hardcoded deny rules cannot be overridden by YAML allow."""
        # Try to allow 'cd' via YAML (should not work - hardcoded deny wins)
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  allow:
    - "^cd"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        result = match_rule('Bash', 'cd /tmp')
        assert result is not None
        assert result[0] == 'deny'  # Hardcoded deny wins

    def test_yaml_allow_works_for_non_hardcoded(self, tmp_path, monkeypatch):
        """Test YAML allow rules work for patterns not in hardcoded rules."""
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  allow:
    - "^my-custom-command"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        result = match_rule('Bash', 'my-custom-command arg1')
        assert result is not None
        assert result[0] == 'allow'
        assert 'local' in result[1]  # Source should indicate YAML

    def test_yaml_deny_adds_new_denials(self, tmp_path, monkeypatch):
        """Test YAML deny rules add new denial patterns."""
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  deny:
    - "^npm run deploy:prod"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        result = match_rule('Bash', 'npm run deploy:prod')
        assert result is not None
        assert result[0] == 'deny'
        assert 'local' in result[1]

    def test_invalid_regex_skipped(self, tmp_path, monkeypatch):
        """Test invalid regex patterns are skipped without crashing."""
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  allow:
    - "[invalid(regex"
    - "^valid-pattern"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        # Should not crash, and valid pattern should still work
        result = match_rule('Bash', 'valid-pattern test')
        assert result is not None
        assert result[0] == 'allow'


class TestSourceTagging:
    """Tests for source tagging in match_rule results."""

    def test_hardcoded_rules_tagged(self):
        """Test hardcoded rules are tagged with 'rules:hardcoded'."""
        result = match_rule('Bash', 'cd /tmp')
        assert result is not None
        assert 'hardcoded' in result[1]

    def test_project_yaml_rules_tagged(self, tmp_path, monkeypatch):
        """Test project YAML rules are tagged with 'rules:project'."""
        (tmp_path / ".agentize.yaml").write_text("""
permissions:
  allow:
    - "^project-specific-cmd"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        result = match_rule('Bash', 'project-specific-cmd')
        assert result is not None
        assert 'project' in result[1]

    def test_local_yaml_rules_tagged(self, tmp_path, monkeypatch):
        """Test local YAML rules are tagged with 'rules:local'."""
        (tmp_path / ".agentize.local.yaml").write_text("""
permissions:
  allow:
    - "^local-specific-cmd"
""")
        monkeypatch.chdir(tmp_path)
        clear_yaml_cache()

        result = match_rule('Bash', 'local-specific-cmd')
        assert result is not None
        assert 'local' in result[1]
