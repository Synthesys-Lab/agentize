"""Pytest configuration and fixtures for agentize.server tests."""

import os
import sys
import urllib.request
from pathlib import Path

import pytest


def _find_project_root() -> Path:
    """Find the project root by walking up from this file."""
    current = Path(__file__).resolve()
    # Walk up: tests/ -> python/ -> project_root
    return current.parent.parent.parent


# Set up paths before any imports
PROJECT_ROOT = _find_project_root()
PYTHON_PATH = PROJECT_ROOT / "python"
CLAUDE_PLUGIN_PATH = PROJECT_ROOT / ".claude-plugin"

# Add python/ to sys.path for imports
if str(PYTHON_PATH) not in sys.path:
    sys.path.insert(0, str(PYTHON_PATH))

# Add .claude-plugin to sys.path for lib.workflow and lib.session_utils imports
if str(CLAUDE_PLUGIN_PATH) not in sys.path:
    sys.path.insert(0, str(CLAUDE_PLUGIN_PATH))


@pytest.fixture
def project_root() -> Path:
    """Return the project root path."""
    return PROJECT_ROOT


@pytest.fixture
def set_agentize_home(tmp_path, monkeypatch):
    """Set AGENTIZE_HOME to a temporary directory."""
    monkeypatch.setenv("AGENTIZE_HOME", str(tmp_path))
    return tmp_path


@pytest.fixture
def clear_local_config_cache():
    """Clear local_config cache before and after test to ensure fresh YAML loading."""
    from lib.local_config import clear_cache
    clear_cache()
    yield
    clear_cache()


@pytest.fixture(autouse=True)
def block_telegram_requests(monkeypatch):
    """Prevent Telegram API calls during tests."""
    original_urlopen = urllib.request.urlopen

    def guard_urlopen(request, *args, **kwargs):
        url = request.full_url if hasattr(request, "full_url") else str(request)
        if isinstance(url, bytes):
            url = url.decode("utf-8", errors="ignore")
        if url.startswith("https://api.telegram.org/"):
            raise RuntimeError("Telegram API requests are disabled during tests.")
        return original_urlopen(request, *args, **kwargs)

    monkeypatch.setattr(urllib.request, "urlopen", guard_urlopen)
