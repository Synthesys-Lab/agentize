"""Runtime configuration loader for .agentize.local.yaml files.

This module handles loading server-specific settings that shouldn't be committed:
- Handsoff mode settings (enabled, max_continuations, auto_permission, debug, supervisor)
- Server settings (period, num_workers)
- Telegram credentials (enabled, token, chat_id, timeout_sec, poll_interval_sec, allowed_user_ids)
- Workflow model assignments (impl, refine, dev_req, rebase)

Configuration precedence: CLI args > env vars > .agentize.local.yaml > defaults
"""

from pathlib import Path
from typing import Any

# Valid top-level keys in .agentize.local.yaml
# Extended to include handsoff and metadata keys for unified local configuration
VALID_TOP_LEVEL_KEYS = {
    "server", "telegram", "workflows",  # Original keys
    "handsoff",  # Handsoff mode settings
    "project", "git", "agentize", "worktree", "pre_commit",  # Metadata keys (shared with .agentize.yaml)
    "permissions",  # User-configurable permission rules
}

# Valid workflow names
VALID_WORKFLOW_NAMES = {"impl", "refine", "dev_req", "rebase"}

# Valid model values
VALID_MODELS = {"opus", "sonnet", "haiku"}


def load_runtime_config(start_dir: Path | None = None) -> tuple[dict, Path | None]:
    """Load runtime configuration from .agentize.local.yaml.

    Searches from start_dir up to parent directories until the config file is found.

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Tuple of (config_dict, config_path). config_path is None if file not found.

    Raises:
        ValueError: If the config file contains unknown top-level keys or invalid structure.
    """
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

    # Validate top-level keys
    for key in config:
        if key not in VALID_TOP_LEVEL_KEYS:
            raise ValueError(
                f"Unknown top-level key '{key}' in {config_path}. "
                f"Valid keys: {', '.join(sorted(VALID_TOP_LEVEL_KEYS))}"
            )

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


def resolve_precedence(
    cli_value: Any | None,
    env_value: Any | None,
    config_value: Any | None,
    default: Any | None,
) -> Any | None:
    """Return first non-None value in precedence order.

    Precedence: CLI > env > config > default

    Args:
        cli_value: Value from CLI argument
        env_value: Value from environment variable
        config_value: Value from .agentize.local.yaml
        default: Default value

    Returns:
        First non-None value, or default if all are None
    """
    if cli_value is not None:
        return cli_value
    if env_value is not None:
        return env_value
    if config_value is not None:
        return config_value
    return default


def extract_workflow_models(config: dict) -> dict[str, str]:
    """Extract workflow -> model mapping from config.

    Args:
        config: Parsed config dict from load_runtime_config()

    Returns:
        Dict mapping workflow names to model names.
        Only includes workflows that have a model configured.
        Example: {"impl": "opus", "refine": "sonnet"}
    """
    workflows = config.get("workflows", {})
    if not isinstance(workflows, dict):
        return {}

    models = {}
    for workflow_name, workflow_config in workflows.items():
        if workflow_name not in VALID_WORKFLOW_NAMES:
            continue
        if not isinstance(workflow_config, dict):
            continue
        model = workflow_config.get("model")
        if model and model in VALID_MODELS:
            models[workflow_name] = model

    return models
