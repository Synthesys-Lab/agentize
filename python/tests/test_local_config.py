"""Tests for .claude-plugin/lib/local_config.py YAML config loading and env override."""

import os
import pytest
from pathlib import Path


# Add .claude-plugin to path for imports
import sys
project_root = Path(__file__).resolve().parents[2]
plugin_dir = project_root / ".claude-plugin"
sys.path.insert(0, str(plugin_dir))

from lib.local_config import (
    load_local_config,
    get_local_value,
    coerce_bool,
    coerce_int,
    coerce_csv_ints,
    _get_nested_value,
    clear_cache,
)


@pytest.fixture(autouse=True)
def clear_config_cache():
    """Clear the local config cache before each test."""
    clear_cache()
    yield
    clear_cache()


class TestLoadLocalConfig:
    """Tests for load_local_config function."""

    def test_load_local_config_returns_empty_when_not_found(self, tmp_path):
        """Test load_local_config returns empty dict when file not found."""
        config, path = load_local_config(tmp_path)

        assert config == {}
        assert path is None

    def test_load_local_config_parses_handsoff_section(self, tmp_path):
        """Test load_local_config parses handsoff section with nested keys."""
        config_content = """
handsoff:
  enabled: true
  max_continuations: 15
  auto_permission: false
  debug: true
  supervisor:
    provider: claude
    model: opus
    flags: "--timeout 900"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_local_config(tmp_path)

        assert path is not None
        assert config.get("handsoff", {}).get("enabled") == "true"
        assert config.get("handsoff", {}).get("max_continuations") == 15
        assert config.get("handsoff", {}).get("supervisor", {}).get("provider") == "claude"

    def test_load_local_config_parses_telegram_section(self, tmp_path):
        """Test load_local_config parses telegram section with all fields."""
        config_content = """
telegram:
  enabled: true
  token: "123456:ABC-DEF"
  chat_id: "-1001234567890"
  timeout_sec: 120
  poll_interval_sec: 3
  allowed_user_ids: "123,456,789"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        config, path = load_local_config(tmp_path)

        assert path is not None
        assert config.get("telegram", {}).get("enabled") == "true"
        assert config.get("telegram", {}).get("token") == "123456:ABC-DEF"
        assert config.get("telegram", {}).get("allowed_user_ids") == "123,456,789"

    def test_load_local_config_searches_parent_directories(self, tmp_path):
        """Test load_local_config searches parent directories."""
        config_content = """
handsoff:
  enabled: true
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Create nested directory
        nested_dir = tmp_path / "subdir" / "nested"
        nested_dir.mkdir(parents=True)

        # Search from nested directory
        config, path = load_local_config(nested_dir)

        assert path is not None
        assert config.get("handsoff", {}).get("enabled") == "true"


class TestGetNestedValue:
    """Tests for _get_nested_value helper function."""

    def test_get_nested_value_simple_path(self):
        """Test _get_nested_value with simple dotted path."""
        config = {"handsoff": {"enabled": True}}
        result = _get_nested_value(config, "handsoff.enabled")
        assert result is True

    def test_get_nested_value_deep_path(self):
        """Test _get_nested_value with deeply nested path."""
        config = {"handsoff": {"supervisor": {"provider": "claude"}}}
        result = _get_nested_value(config, "handsoff.supervisor.provider")
        assert result == "claude"

    def test_get_nested_value_missing_key(self):
        """Test _get_nested_value returns None for missing key."""
        config = {"handsoff": {"enabled": True}}
        result = _get_nested_value(config, "handsoff.missing")
        assert result is None

    def test_get_nested_value_partial_path(self):
        """Test _get_nested_value returns None for partial path."""
        config = {"handsoff": {"enabled": True}}
        result = _get_nested_value(config, "handsoff.enabled.extra")
        assert result is None


class TestGetLocalValue:
    """Tests for get_local_value function with env override."""

    def test_get_local_value_from_yaml(self, tmp_path, monkeypatch):
        """Test get_local_value reads from YAML when env not set."""
        config_content = """
handsoff:
  max_continuations: 20
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Clear env var
        monkeypatch.delenv("HANDSOFF_MAX_CONTINUATIONS", raising=False)

        # Change to tmp_path for config lookup
        monkeypatch.chdir(tmp_path)

        result = get_local_value("handsoff.max_continuations", "HANDSOFF_MAX_CONTINUATIONS", 10, coerce_int)
        assert result == 20

    def test_get_local_value_env_overrides_yaml(self, tmp_path, monkeypatch):
        """Test get_local_value uses env var over YAML."""
        config_content = """
handsoff:
  max_continuations: 20
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        # Set env var to override
        monkeypatch.setenv("HANDSOFF_MAX_CONTINUATIONS", "50")
        monkeypatch.chdir(tmp_path)

        result = get_local_value("handsoff.max_continuations", "HANDSOFF_MAX_CONTINUATIONS", 10, coerce_int)
        assert result == 50

    def test_get_local_value_uses_default_when_missing(self, tmp_path, monkeypatch):
        """Test get_local_value uses default when both env and YAML missing."""
        config_content = """
handsoff:
  enabled: true
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        monkeypatch.delenv("HANDSOFF_MAX_CONTINUATIONS", raising=False)
        monkeypatch.chdir(tmp_path)

        result = get_local_value("handsoff.max_continuations", "HANDSOFF_MAX_CONTINUATIONS", 10, coerce_int)
        assert result == 10

    def test_get_local_value_no_coercion(self, tmp_path, monkeypatch):
        """Test get_local_value works without coercion function."""
        config_content = """
telegram:
  token: "test-token"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        monkeypatch.delenv("TG_API_TOKEN", raising=False)
        monkeypatch.chdir(tmp_path)

        result = get_local_value("telegram.token", "TG_API_TOKEN", "")
        assert result == "test-token"


class TestCoerceBool:
    """Tests for coerce_bool helper function."""

    def test_coerce_bool_true_values(self):
        """Test coerce_bool accepts various true values."""
        for value in ["true", "True", "TRUE", "1", "on", "ON", "enable", "Enable"]:
            assert coerce_bool(value, False) is True

    def test_coerce_bool_false_values(self):
        """Test coerce_bool accepts various false values."""
        for value in ["false", "False", "FALSE", "0", "off", "OFF", "disable", "Disable"]:
            assert coerce_bool(value, True) is False

    def test_coerce_bool_default_on_invalid(self):
        """Test coerce_bool returns default for invalid values."""
        assert coerce_bool("invalid", True) is True
        assert coerce_bool("invalid", False) is False

    def test_coerce_bool_with_actual_bool(self):
        """Test coerce_bool handles actual boolean values."""
        assert coerce_bool(True, False) is True
        assert coerce_bool(False, True) is False


class TestCoerceInt:
    """Tests for coerce_int helper function."""

    def test_coerce_int_from_string(self):
        """Test coerce_int converts string to int."""
        assert coerce_int("42", 0) == 42
        assert coerce_int("100", 0) == 100

    def test_coerce_int_from_int(self):
        """Test coerce_int passes through int values."""
        assert coerce_int(42, 0) == 42

    def test_coerce_int_default_on_invalid(self):
        """Test coerce_int returns default for invalid values."""
        assert coerce_int("invalid", 10) == 10
        assert coerce_int("", 5) == 5


class TestCoerceCsvInts:
    """Tests for coerce_csv_ints helper function."""

    def test_coerce_csv_ints_parses_csv(self):
        """Test coerce_csv_ints parses comma-separated integers."""
        result = coerce_csv_ints("123,456,789")
        assert result == [123, 456, 789]

    def test_coerce_csv_ints_single_value(self):
        """Test coerce_csv_ints handles single value."""
        result = coerce_csv_ints("123")
        assert result == [123]

    def test_coerce_csv_ints_with_spaces(self):
        """Test coerce_csv_ints handles spaces around values."""
        result = coerce_csv_ints(" 123 , 456 , 789 ")
        assert result == [123, 456, 789]

    def test_coerce_csv_ints_empty_string(self):
        """Test coerce_csv_ints returns empty list for empty string."""
        result = coerce_csv_ints("")
        assert result == []

    def test_coerce_csv_ints_invalid_values(self):
        """Test coerce_csv_ints skips invalid values."""
        result = coerce_csv_ints("123,invalid,456")
        # Should skip 'invalid' and return valid integers
        assert 123 in result
        assert 456 in result


class TestEnvOverridePrecedence:
    """Tests for environment variable override precedence."""

    def test_env_override_for_handsoff_enabled(self, tmp_path, monkeypatch):
        """Test HANDSOFF_MODE env overrides handsoff.enabled YAML."""
        config_content = """
handsoff:
  enabled: false
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        monkeypatch.setenv("HANDSOFF_MODE", "1")
        monkeypatch.chdir(tmp_path)

        result = get_local_value("handsoff.enabled", "HANDSOFF_MODE", True, coerce_bool)
        assert result is True

    def test_env_override_for_telegram_token(self, tmp_path, monkeypatch):
        """Test TG_API_TOKEN env overrides telegram.token YAML."""
        config_content = """
telegram:
  token: "yaml-token"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        monkeypatch.setenv("TG_API_TOKEN", "env-token")
        monkeypatch.chdir(tmp_path)

        result = get_local_value("telegram.token", "TG_API_TOKEN", "")
        assert result == "env-token"

    def test_yaml_used_when_env_not_set(self, tmp_path, monkeypatch):
        """Test YAML value used when env var not set."""
        config_content = """
telegram:
  token: "yaml-token"
"""
        config_file = tmp_path / ".agentize.local.yaml"
        config_file.write_text(config_content)

        monkeypatch.delenv("TG_API_TOKEN", raising=False)
        monkeypatch.chdir(tmp_path)

        result = get_local_value("telegram.token", "TG_API_TOKEN", "default")
        assert result == "yaml-token"
