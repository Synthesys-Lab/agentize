"""Local configuration loader for .agentize.local.yaml files.

This module provides YAML-only configuration for hooks. It loads developer-specific
settings (handsoff, Telegram, server) from .agentize.local.yaml.

YAML search order:
1. Project root .agentize.local.yaml
2. $AGENTIZE_HOME/.agentize.local.yaml
3. $HOME/.agentize.local.yaml (user-wide, created by installer)

Configuration precedence: .agentize.local.yaml > defaults

Note: This module caches config for hooks. Server runtime_config intentionally
bypasses cache to ensure fresh config on each poll cycle.
"""

from pathlib import Path
from typing import Any, Callable, Optional

from lib.local_config_io import find_local_config_file, parse_yaml_file

# Module-level cache for loaded config
_cached_config: Optional[dict] = None
_cached_path: Optional[Path] = None


def load_local_config(start_dir: Optional[Path] = None) -> tuple[dict, Optional[Path]]:
    """Load local configuration from .agentize.local.yaml.

    Search order:
    1. Walk up from start_dir to parent directories
    2. Try $AGENTIZE_HOME/.agentize.local.yaml
    3. Try $HOME/.agentize.local.yaml

    Results are cached for subsequent calls when start_dir is None (default).
    This avoids repeated file I/O during permission checks in hooks.

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Tuple of (config_dict, config_path). config_path is None if file not found.
    """
    global _cached_config, _cached_path

    # Use cached config if available and no specific start_dir provided
    if _cached_config is not None and start_dir is None:
        return _cached_config, _cached_path

    # Use shared helper to find config file
    config_path = find_local_config_file(start_dir)

    if config_path is None:
        return {}, None

    # Use shared helper to parse YAML
    config = parse_yaml_file(config_path)

    # Cache for subsequent calls (only when using default start_dir)
    if start_dir is None:
        _cached_config = config
        _cached_path = config_path

    return config, config_path


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
    default: Any,
    coerce: Optional[Callable[[Any, Any], Any]] = None
) -> Any:
    """Get a config value from YAML only.

    Precedence: YAML value > default

    Args:
        path: Dotted path to YAML value (e.g., 'handsoff.enabled')
        default: Default value if not found
        coerce: Optional coercion function (e.g., coerce_bool, coerce_int)

    Returns:
        Resolved value with coercion applied
    """
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
