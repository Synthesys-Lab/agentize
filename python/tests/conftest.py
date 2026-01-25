"""Pytest configuration and fixtures for agentize.server tests."""

import os
import sys
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
