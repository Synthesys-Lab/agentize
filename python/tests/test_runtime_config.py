"""Tests for agentize.server runtime configuration loading and precedence."""

import pytest
from pathlib import Path

from agentize.server.runtime_config import (
    load_runtime_config,
    resolve_precedence,
    extract_workflow_models,
)


class TestLoadRuntimeConfig:
    """Tests for load_runtime_config function."""

    def test_load_runtime_config_returns_empty_when_not_found(self, tmp_path):
        """Test load_runtime_config returns empty dict when file not found."""
        config, path = load_runtime_config(Path("/nonexistent/path"))

        assert config == {}
        assert path is None

    def test_load_runtime_config_parses_all_sections(self, tmp_path):
        """Test load_runtime_config parses nested server, telegram, workflows sections."""
        config_content = """
server:
  period: 5m
  num_workers: 3

telegram:
  token: "test-token"
  chat_id: 12345

workflows:
  impl:
    model: opus
  refine:
    model: sonnet
  dev_req:
    model: sonnet
  rebase:
    model: haiku
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_runtime_config(tmp_path)

        # Check server section
        assert config.get("server", {}).get("period") == "5m"
        assert config.get("server", {}).get("num_workers") == 3

        # Check telegram section
        assert config.get("telegram", {}).get("token") == "test-token"
        # YAML parses unquoted numbers as integers
        assert config.get("telegram", {}).get("chat_id") == 12345

        # Check workflows section
        assert config.get("workflows", {}).get("impl", {}).get("model") == "opus"
        assert config.get("workflows", {}).get("refine", {}).get("model") == "sonnet"
        assert config.get("workflows", {}).get("rebase", {}).get("model") == "haiku"

    def test_load_runtime_config_searches_parent_directories(self, tmp_path):
        """Test load_runtime_config searches parent directories."""
        config_content = """
telegram:
  token: "test-token"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Create nested directory
        nested_dir = tmp_path / "subdir" / "nested"
        nested_dir.mkdir(parents=True)

        # Search from nested directory, should find config in parent
        config, path = load_runtime_config(nested_dir)

        found = (
            path is not None
            and "test-token" in config.get("telegram", {}).get("token", "")
        )
        assert found

    def test_load_runtime_config_raises_for_unknown_key(self, tmp_path):
        """Test load_runtime_config raises ValueError for unknown top-level key."""
        config_content = """
server:
  period: 5m
unknown_section:
  foo: bar
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        with pytest.raises(ValueError) as exc_info:
            load_runtime_config(tmp_path)

        assert "unknown" in str(exc_info.value).lower()


class TestResolvePrecedence:
    """Tests for resolve_precedence helper function."""

    def test_resolve_precedence_cli_takes_precedence(self):
        """Test CLI argument takes precedence over config."""
        result = resolve_precedence(
            cli_value="10m", env_value=None, config_value="5m", default="1m"
        )
        assert result == "10m"

    def test_resolve_precedence_env_over_config(self):
        """Test env takes precedence over config."""
        result = resolve_precedence(
            cli_value=None,
            env_value="env-token",
            config_value="config-token",
            default=None,
        )
        assert result == "env-token"

    def test_resolve_precedence_config_over_default(self):
        """Test config takes precedence over default."""
        result = resolve_precedence(
            cli_value=None,
            env_value=None,
            config_value="from-config",
            default="from-default",
        )
        assert result == "from-config"

    def test_resolve_precedence_uses_default(self):
        """Test default used when nothing else provided."""
        result = resolve_precedence(
            cli_value=None, env_value=None, config_value=None, default="default-value"
        )
        assert result == "default-value"


class TestExtractWorkflowModels:
    """Tests for extract_workflow_models helper function."""

    def test_extract_workflow_models_returns_all_models(self, tmp_path):
        """Test extract_workflow_models returns all workflow models."""
        config_content = """
workflows:
  impl:
    model: opus
  refine:
    model: sonnet
  dev_req:
    model: sonnet
  rebase:
    model: haiku
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, _ = load_runtime_config(tmp_path)
        models = extract_workflow_models(config)

        assert models.get("impl") == "opus"
        assert models.get("refine") == "sonnet"
        assert models.get("dev_req") == "sonnet"
        assert models.get("rebase") == "haiku"

    def test_extract_workflow_models_empty_when_no_workflows(self, tmp_path):
        """Test extract_workflow_models returns empty dict when no workflows section."""
        config_content = """
server:
  period: 5m
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, _ = load_runtime_config(tmp_path)
        models = extract_workflow_models(config)

        assert len(models) == 0


class TestHandsoffSection:
    """Tests for handsoff section parsing in .agentize.local.yaml."""

    def test_load_runtime_config_parses_handsoff_section(self, tmp_path):
        """Test load_runtime_config parses handsoff section with all nested keys."""
        config_content = """
handsoff:
  enabled: true
  max_continuations: 20
  auto_permission: true
  debug: false
  supervisor:
    provider: claude
    model: opus
    flags: "--timeout 1800"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_runtime_config(tmp_path)

        assert path is not None
        assert config.get("handsoff", {}).get("enabled") is True
        assert config.get("handsoff", {}).get("max_continuations") == 20
        assert config.get("handsoff", {}).get("auto_permission") is True
        assert config.get("handsoff", {}).get("debug") is False
        assert config.get("handsoff", {}).get("supervisor", {}).get("provider") == "claude"
        assert config.get("handsoff", {}).get("supervisor", {}).get("model") == "opus"
        assert config.get("handsoff", {}).get("supervisor", {}).get("flags") == "--timeout 1800"

    def test_load_runtime_config_parses_telegram_extended_section(self, tmp_path):
        """Test load_runtime_config parses extended telegram section."""
        config_content = """
telegram:
  enabled: true
  token: "test-token"
  chat_id: -1001234567890
  timeout_sec: 120
  poll_interval_sec: 10
  allowed_user_ids: "123,456,789"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_runtime_config(tmp_path)

        assert path is not None
        assert config.get("telegram", {}).get("enabled") is True
        assert config.get("telegram", {}).get("token") == "test-token"
        # Note: YAML parser converts numeric strings to int (negative numbers work)
        assert config.get("telegram", {}).get("chat_id") == -1001234567890
        assert config.get("telegram", {}).get("timeout_sec") == 120
        assert config.get("telegram", {}).get("poll_interval_sec") == 10
        assert config.get("telegram", {}).get("allowed_user_ids") == "123,456,789"

    def test_load_runtime_config_accepts_all_valid_top_level_keys(self, tmp_path):
        """Test load_runtime_config accepts all extended top-level keys."""
        config_content = """
handsoff:
  enabled: true

server:
  period: 5m

telegram:
  token: "test"

workflows:
  impl:
    model: opus

project:
  name: test

git:
  default_branch: main

agentize:
  commit: abc123

worktree:
  trees_dir: trees

pre_commit:
  enabled: true
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Should not raise ValueError
        config, path = load_runtime_config(tmp_path)

        assert path is not None
        assert "handsoff" in config
        assert "server" in config
        assert "telegram" in config
        assert "workflows" in config
        assert "project" in config
        assert "git" in config
        assert "agentize" in config
        assert "worktree" in config
        assert "pre_commit" in config

    def test_load_runtime_config_accepts_permissions_key(self, tmp_path):
        """Test load_runtime_config accepts permissions key with array values."""
        config_content = """
permissions:
  allow:
    - '^npm run build'
    - pattern: '^cat .*\\.md$'
      tool: Read
  deny:
    - '^rm -rf'
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Should not raise ValueError
        config, path = load_runtime_config(tmp_path)

        assert path is not None
        assert "permissions" in config
        permissions = config.get("permissions", {})
        assert "allow" in permissions
        assert "deny" in permissions

    def test_load_runtime_config_parses_permission_arrays(self, tmp_path):
        """Test runtime_config parses permission arrays correctly."""
        config_content = """
permissions:
  allow:
    - '^npm run build'
    - '^make test'
    - pattern: '^cat .*\\.md$'
      tool: Read
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_runtime_config(tmp_path)

        allow = config.get("permissions", {}).get("allow", [])
        assert isinstance(allow, list)
        assert len(allow) == 3
        assert allow[0] == "^npm run build"
        assert allow[1] == "^make test"
        assert isinstance(allow[2], dict)
        assert allow[2].get("pattern") == "^cat .*\\.md$"
        assert allow[2].get("tool") == "Read"


class TestServerParameterPrecedence:
    """Tests for server parameter (period, num_workers) precedence resolution.

    Note: CLI flags are no longer supported for server parameters.
    Configuration is YAML-only: .agentize.local.yaml > defaults
    """

    def test_resolve_precedence_period_yaml_overrides_default(self):
        """Test YAML server.period: 2m overrides default 5m."""
        result = resolve_precedence(
            cli_value=None, env_value=None, config_value="2m", default="5m"
        )
        assert result == "2m"

    def test_resolve_precedence_num_workers_yaml_overrides_default(self):
        """Test YAML server.num_workers: 3 overrides default 5."""
        result = resolve_precedence(
            cli_value=None, env_value=None, config_value=3, default=5
        )
        assert result == 3

    def test_resolve_precedence_uses_defaults_when_no_yaml(self):
        """Test defaults are used when YAML file absent."""
        result_period = resolve_precedence(
            cli_value=None, env_value=None, config_value=None, default="5m"
        )
        result_workers = resolve_precedence(
            cli_value=None, env_value=None, config_value=None, default=5
        )
        assert result_period == "5m"
        assert result_workers == 5
