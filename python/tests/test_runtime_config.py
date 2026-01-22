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
  chat_id: "12345"

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
