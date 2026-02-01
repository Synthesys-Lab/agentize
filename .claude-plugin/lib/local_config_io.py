"""Shared YAML file discovery and parsing helpers for .agentize.local.yaml.

This module provides a single source of truth for YAML file search order and
parsing logic. Both local_config.py (hooks) and runtime_config.py (server)
use these helpers to ensure consistent behavior.

Note: This module does NOT cache results. Caching is handled by callers:
- local_config.py caches for hooks (avoid repeated I/O during permission checks)
- runtime_config.py does not cache (server needs fresh config each poll cycle)
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

try:
    import yaml
except ModuleNotFoundError:  # Optional dependency for full YAML support
    yaml = None


def find_local_config_file(start_dir: Optional[Path] = None) -> Optional[Path]:
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


def _strip_inline_comment(line: str) -> str:
    """Strip YAML comments while preserving quoted strings."""
    if "#" not in line:
        return line

    in_single = False
    in_double = False
    for idx, char in enumerate(line):
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            return line[:idx].rstrip()
    return line


def _parse_scalar(value: str):
    """Parse a scalar YAML value into Python types."""
    text = value.strip()
    if text == "":
        return ""

    if (text.startswith('"') and text.endswith('"')) or (text.startswith("'") and text.endswith("'")):
        return text[1:-1]

    lower = text.lower()
    if lower in ("true", "yes", "on"):
        return True
    if lower in ("false", "no", "off"):
        return False
    if lower in ("null", "none", "~"):
        return None

    if lower in ("|", ">"):
        raise ValueError("Block scalars are not supported without PyYAML installed")

    if text.lstrip("-").isdigit():
        try:
            return int(text)
        except ValueError:
            pass

    try:
        if "." in text:
            return float(text)
    except ValueError:
        pass

    return text


def _split_key_value(content: str) -> tuple[str, Optional[str]]:
    """Split a YAML mapping line into key and value."""
    if ":" not in content:
        raise ValueError(f"Invalid YAML mapping line: {content}")

    key, rest = content.split(":", 1)
    key = key.strip()
    if key == "":
        raise ValueError(f"Empty YAML key in line: {content}")

    value = rest.strip()
    if value == "":
        return key, None
    return key, value


def _prepare_lines(content: str) -> list[tuple[int, str]]:
    """Normalize YAML lines into (indent, content) tuples."""
    lines: list[tuple[int, str]] = []
    for raw_line in content.splitlines():
        stripped = _strip_inline_comment(raw_line.rstrip("\n"))
        if not stripped.strip():
            continue
        indent = len(stripped) - len(stripped.lstrip(" "))
        if "\t" in stripped[:indent]:
            raise ValueError("Tabs are not supported for YAML indentation")
        lines.append((indent, stripped.lstrip(" ")))
    return lines


def _parse_block(lines: list[tuple[int, str]], index: int, indent: int):
    """Parse a YAML block starting at index with the given indent."""
    if index >= len(lines):
        return {}, index

    if lines[index][0] != indent:
        raise ValueError("Invalid YAML indentation")

    is_list = lines[index][1].startswith("- ")
    if is_list:
        items = []
        while index < len(lines):
            line_indent, content = lines[index]
            if line_indent < indent:
                break
            if line_indent > indent:
                raise ValueError("Unexpected indent in YAML list")
            if not content.startswith("- "):
                break

            item_text = content[2:].strip()
            index += 1

            if item_text == "":
                if index < len(lines) and lines[index][0] > indent:
                    nested_indent = lines[index][0]
                    nested_value, index = _parse_block(lines, index, nested_indent)
                    items.append(nested_value)
                else:
                    items.append(None)
                continue

            if ":" in item_text:
                key, value = _split_key_value(item_text)
                item_dict: dict = {}
                if value is None:
                    if index < len(lines) and lines[index][0] > indent:
                        nested_indent = lines[index][0]
                        nested_value, index = _parse_block(lines, index, nested_indent)
                        item_dict[key] = nested_value
                    else:
                        item_dict[key] = {}
                else:
                    item_dict[key] = _parse_scalar(value)

                if index < len(lines) and lines[index][0] > indent:
                    nested_indent = lines[index][0]
                    extra, index = _parse_block(lines, index, nested_indent)
                    if isinstance(extra, dict):
                        item_dict.update(extra)
                items.append(item_dict)
                continue

            items.append(_parse_scalar(item_text))
        return items, index

    data: dict = {}
    while index < len(lines):
        line_indent, content = lines[index]
        if line_indent < indent:
            break
        if line_indent > indent:
            raise ValueError("Unexpected indent in YAML mapping")
        if content.startswith("- "):
            raise ValueError("Unexpected list item in YAML mapping")

        key, value = _split_key_value(content)
        index += 1

        if value is None:
            if index < len(lines) and lines[index][0] > indent:
                nested_indent = lines[index][0]
                nested_value, index = _parse_block(lines, index, nested_indent)
                data[key] = nested_value
            else:
                data[key] = {}
        else:
            data[key] = _parse_scalar(value)

    return data, index


def _parse_yaml_fallback(content: str) -> dict:
    """Parse a minimal YAML subset when PyYAML is unavailable."""
    lines = _prepare_lines(content)
    if not lines:
        return {}

    value, index = _parse_block(lines, 0, lines[0][0])
    if index < len(lines):
        remaining = lines[index:]
        if any(part[0] == lines[0][0] for part in remaining):
            raise ValueError("Unexpected trailing YAML content")

    if not isinstance(value, dict):
        raise ValueError("Top-level YAML must be a mapping")

    return value


def parse_yaml_file(path: Path) -> dict:
    """Parse a YAML file using yaml.safe_load() when available.

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict. Returns {} on empty content.
    """
    with open(path, "r") as f:
        content = f.read()

    if yaml is not None:
        return yaml.safe_load(content) or {}

    return _parse_yaml_fallback(content)
