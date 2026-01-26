"""Shared YAML file discovery and parsing helpers for .agentize.local.yaml.

This module provides a single source of truth for YAML file search order and
parsing logic. Both local_config.py (hooks) and runtime_config.py (server)
use these helpers to ensure consistent behavior.

Note: This module does NOT cache results. Caching is handled by callers:
- local_config.py caches for hooks (avoid repeated I/O during permission checks)
- runtime_config.py does not cache (server needs fresh config each poll cycle)
"""

import os
from pathlib import Path

import yaml


def find_local_config_file(start_dir: Path | None = None) -> Path | None:
    """Find .agentize.local.yaml using the standard search order.

    Search order:
    1. Walk up from start_dir to parent directories
    2. Check $AGENTIZE_HOME/.agentize.local.yaml
    3. Check $HOME/.agentize.local.yaml

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Path to the config file if found, None otherwise.
    """
    if start_dir is None:
        start_dir = Path.cwd()

    start_dir = Path(start_dir).resolve()

    # Search from start_dir up to parent directories
    current = start_dir
    while True:
        candidate = current / ".agentize.local.yaml"
        if candidate.is_file():
            return candidate

        parent = current.parent
        if parent == current:
            # Reached root
            break
        current = parent

    # Fallback 1: Try $AGENTIZE_HOME
    agentize_home = os.getenv("AGENTIZE_HOME")
    if agentize_home:
        candidate = Path(agentize_home) / ".agentize.local.yaml"
        if candidate.is_file():
            return candidate

    # Fallback 2: Try $HOME (user-wide config)
    home = os.getenv("HOME")
    if home:
        candidate = Path(home) / ".agentize.local.yaml"
        if candidate.is_file():
            return candidate

    return None


def parse_yaml_file(path: Path) -> dict:
    """Parse a YAML file using yaml.safe_load().

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict. Returns {} on empty content.
    """
    with open(path, "r") as f:
        return yaml.safe_load(f) or {}
