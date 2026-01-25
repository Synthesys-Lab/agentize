"""Local configuration loader for .agentize.local.yaml files.

This module provides YAML-only configuration for hooks. It loads developer-specific
settings (handsoff, Telegram, server) from .agentize.local.yaml.

YAML search order:
1. Project root .agentize.local.yaml
2. $AGENTIZE_HOME/.agentize.local.yaml
3. $HOME/.agentize.local.yaml (user-wide, created by installer)

Configuration precedence: .agentize.local.yaml > defaults
"""

import os
from pathlib import Path
from typing import Any, Callable, Optional

# Module-level cache for loaded config
_cached_config: Optional[dict] = None
_cached_path: Optional[Path] = None


def load_local_config(start_dir: Optional[Path] = None) -> tuple[dict, Optional[Path]]:
    """Load local configuration from .agentize.local.yaml.

    Search order:
    1. Walk up from start_dir to parent directories
    2. Try $AGENTIZE_HOME/.agentize.local.yaml
    3. Try $HOME/.agentize.local.yaml

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

    # Fallback 1: Try $AGENTIZE_HOME
    if config_path is None:
        agentize_home = os.getenv("AGENTIZE_HOME")
        if agentize_home:
            candidate = Path(agentize_home) / ".agentize.local.yaml"
            if candidate.is_file():
                config_path = candidate

    # Fallback 2: Try $HOME (user-wide config)
    if config_path is None:
        home = os.getenv("HOME")
        if home:
            candidate = Path(home) / ".agentize.local.yaml"
            if candidate.is_file():
                config_path = candidate

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

    Supports basic YAML structure with nested dicts and arrays.
    Arrays are supported as:
      - "- value"  (scalar items)
      - "- key: value" (dict items with subsequent indented key-values)

    Does not support anchors, flow-style syntax, or multi-line literals.

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict
    """
    lines: list[tuple[int, str]] = []

    with open(path, "r") as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(line) - len(line.lstrip())
            lines.append((indent, stripped))

    return _parse_lines(lines, 0, len(lines), -1)


def _parse_lines(lines: list[tuple[int, str]], start: int, end: int, parent_indent: int) -> dict:
    """Parse a range of lines into a dict, handling nested structures."""
    result: dict[str, Any] = {}
    i = start

    while i < end:
        indent, stripped = lines[i]

        # Skip lines that are less indented than our scope
        if indent <= parent_indent and i > start:
            break

        if stripped.startswith("- "):
            # This shouldn't happen at dict level - skip
            i += 1
            continue

        if ":" not in stripped:
            i += 1
            continue

        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()

        # Remove quotes from value if present
        if value and value[0] in ('"', "'") and value[-1] == value[0]:
            value = value[1:-1]

        if value:
            # Simple key: value
            try:
                result[key] = int(value)
            except ValueError:
                result[key] = value
            i += 1
        else:
            # Key with no value - check what follows
            i += 1
            if i < end:
                next_indent, next_stripped = lines[i]
                if next_indent > indent:
                    if next_stripped.startswith("- "):
                        # It's a list
                        result[key], i = _parse_list(lines, i, end, indent)
                    else:
                        # It's a nested dict
                        child_end = _find_block_end(lines, i, end, indent)
                        result[key] = _parse_lines(lines, i, child_end, indent)
                        i = child_end
                else:
                    # Empty value
                    result[key] = {}
            else:
                result[key] = {}

    return result


def _parse_list(lines: list[tuple[int, str]], start: int, end: int, parent_indent: int) -> tuple[list, int]:
    """Parse a list starting at the given position."""
    result: list[Any] = []
    i = start

    while i < end:
        indent, stripped = lines[i]

        # Stop if we've de-indented past the list level
        if indent <= parent_indent:
            break

        if not stripped.startswith("- "):
            # Not a list item - might be continuation of previous dict item
            i += 1
            continue

        item_content = stripped[2:].strip()

        # First check if the entire item is a quoted string (may contain colons)
        if item_content and item_content[0] in ('"', "'") and item_content[-1] == item_content[0]:
            # Scalar item: quoted string
            item_value = item_content[1:-1]
            result.append(item_value)
            i += 1
        elif ":" in item_content:
            # Dict item: "- key: value"
            key, _, value = item_content.partition(":")
            key = key.strip()
            value = value.strip()

            # Remove quotes if present
            if value and value[0] in ('"', "'") and value[-1] == value[0]:
                value = value[1:-1]

            item_dict: dict[str, Any] = {}
            if value:
                try:
                    item_dict[key] = int(value)
                except ValueError:
                    item_dict[key] = value
            else:
                item_dict[key] = {}

            i += 1

            # Check for additional keys at deeper indentation
            while i < end:
                next_indent, next_stripped = lines[i]
                if next_indent <= indent:
                    break
                if next_stripped.startswith("- "):
                    break
                if ":" in next_stripped:
                    k, _, v = next_stripped.partition(":")
                    k = k.strip()
                    v = v.strip()
                    if v and v[0] in ('"', "'") and v[-1] == v[0]:
                        v = v[1:-1]
                    if v:
                        try:
                            item_dict[k] = int(v)
                        except ValueError:
                            item_dict[k] = v
                    else:
                        item_dict[k] = {}
                i += 1

            result.append(item_dict)
        else:
            # Scalar item: unquoted value
            item_value: Any = item_content
            try:
                item_value = int(item_value)
            except ValueError:
                pass
            result.append(item_value)
            i += 1

    return result, i


def _find_block_end(lines: list[tuple[int, str]], start: int, end: int, parent_indent: int) -> int:
    """Find where a block ends (where indentation returns to parent level)."""
    i = start
    while i < end:
        indent, _ = lines[i]
        if indent <= parent_indent:
            break
        i += 1
    return i


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
