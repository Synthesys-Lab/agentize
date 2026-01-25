"""Local configuration loader for .agentize.local.yaml files.

This module provides YAML-first configuration for hooks with environment variable override.
It loads developer-specific settings (handsoff, Telegram, server) from .agentize.local.yaml
and allows environment variables to override any setting.

Configuration precedence: env vars > .agentize.local.yaml > defaults
"""

import os
from pathlib import Path
from typing import Any, Callable, Optional

# Module-level cache for loaded config
_cached_config: Optional[dict] = None
_cached_path: Optional[Path] = None


def load_local_config(start_dir: Optional[Path] = None) -> tuple[dict, Optional[Path]]:
    """Load local configuration from .agentize.local.yaml.

    Searches from start_dir up to parent directories until the config file is found.
    Results are cached for subsequent calls.

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Tuple of (config_dict, config_path). config_path is None if file not found.
    """
    global _cached_config, _cached_path

    # Use cached config if available and no specific start_dir provided
    if _cached_config is not None and start_dir is None:
        return _cached_config, _cached_path

    if start_dir is None:
        start_dir = Path.cwd()

    start_dir = Path(start_dir).resolve()

    # Search from start_dir up to parent directories
    current = start_dir
    config_path = None

    while True:
        candidate = current / ".agentize.local.yaml"
        if candidate.is_file():
            config_path = candidate
            break

        parent = current.parent
        if parent == current:
            # Reached root
            break
        current = parent

    if config_path is None:
        return {}, None

    # Parse the YAML file (minimal parser, no external dependencies)
    config = _parse_yaml_file(config_path)

    # Cache for subsequent calls
    if start_dir == Path.cwd():
        _cached_config = config
        _cached_path = config_path

    return config, config_path


def _parse_yaml_file(path: Path) -> dict:
    """Parse a simple YAML file into a nested dict.

    Supports basic YAML structure with nested dicts. Does not support
    arrays, anchors, or complex YAML features.

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict
    """
    config: dict[str, Any] = {}
    stack: list[tuple[dict, int]] = [(config, -1)]  # (dict, indent_level)

    with open(path, "r") as f:
        for line in f:
            # Skip empty lines and comments
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            # Calculate indentation
            indent = len(line) - len(line.lstrip())

            # Parse key-value pair
            if ":" not in stripped:
                continue

            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip()

            # Remove quotes from value if present
            if value and value[0] in ('"', "'") and value[-1] == value[0]:
                value = value[1:-1]

            # Pop stack to find the right parent level
            while stack and stack[-1][1] >= indent:
                stack.pop()

            current_dict = stack[-1][0] if stack else config

            if value:
                # Simple key: value
                # Try to convert to int if possible
                try:
                    current_dict[key] = int(value)
                except ValueError:
                    current_dict[key] = value
            else:
                # Nested dict (key with no value)
                current_dict[key] = {}
                stack.append((current_dict[key], indent))

    return config


def _get_nested_value(config: dict, path: str) -> Any:
    """Get a value from a nested dict using dotted path.

    Args:
        config: Nested dict to search
        path: Dotted path (e.g., 'handsoff.enabled', 'telegram.token')

    Returns:
        Value at path, or None if not found
    """
    parts = path.split('.')
    current = config

    for part in parts:
        if not isinstance(current, dict):
            return None
        current = current.get(part)
        if current is None:
            return None

    return current


def get_local_value(
    path: str,
    env: Optional[str],
    default: Any,
    coerce: Optional[Callable[[Any, Any], Any]] = None
) -> Any:
    """Get a config value with environment variable override.

    Precedence: env var > YAML value > default

    Args:
        path: Dotted path to YAML value (e.g., 'handsoff.enabled')
        env: Environment variable name to check (or None to skip env check)
        default: Default value if not found
        coerce: Optional coercion function (e.g., coerce_bool, coerce_int)

    Returns:
        Resolved value with coercion applied
    """
    # Check environment variable first (highest precedence)
    if env:
        env_value = os.getenv(env)
        if env_value is not None:
            if coerce:
                return coerce(env_value, default)
            return env_value

    # Check YAML config
    config, _ = load_local_config()
    yaml_value = _get_nested_value(config, path)

    if yaml_value is not None:
        if coerce:
            return coerce(yaml_value, default)
        return yaml_value

    # Return default
    return default


def coerce_bool(value: Any, default: bool) -> bool:
    """Coerce a value to boolean.

    Accepts: true, false, 1, 0, on, off, enable, disable (case-insensitive)

    Args:
        value: Value to coerce
        default: Default if coercion fails

    Returns:
        Boolean value
    """
    if isinstance(value, bool):
        return value

    if isinstance(value, (int, float)):
        return bool(value)

    if isinstance(value, str):
        lower = value.lower().strip()
        if lower in ('true', '1', 'on', 'enable'):
            return True
        if lower in ('false', '0', 'off', 'disable'):
            return False

    return default


def coerce_int(value: Any, default: int) -> int:
    """Coerce a value to integer.

    Args:
        value: Value to coerce
        default: Default if coercion fails

    Returns:
        Integer value
    """
    if isinstance(value, int):
        return value

    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            pass

    return default


def coerce_csv_ints(value: Any) -> list[int]:
    """Parse comma-separated user IDs to list of integers.

    Args:
        value: CSV string (e.g., "123,456,789")

    Returns:
        List of integers. Empty list on parse error.
    """
    if not value:
        return []

    if not isinstance(value, str):
        return []

    result = []
    for part in value.split(','):
        part = part.strip()
        if part:
            try:
                result.append(int(part))
            except ValueError:
                continue

    return result


def clear_cache() -> None:
    """Clear the cached configuration.

    Used for testing to ensure fresh config loading.
    """
    global _cached_config, _cached_path
    _cached_config = None
    _cached_path = None
