"""Runtime configuration loader for .agentize.local.yaml files.

This module handles loading server-specific settings that shouldn't be committed:
- Handsoff mode settings (enabled, max_continuations, auto_permission, debug, supervisor)
- Server settings (period, num_workers)
- Telegram credentials (enabled, token, chat_id, timeout_sec, poll_interval_sec, allowed_user_ids)
- Workflow model assignments (impl, refine, dev_req, rebase)

Configuration precedence: CLI args > env vars > .agentize.local.yaml > defaults

Note: This module intentionally does NOT cache config. Server needs fresh config
on each poll cycle to pick up file changes without restart. For hooks that need
caching, use local_config.py instead.
"""

import sys
from pathlib import Path
from typing import Any

# Add .claude-plugin to path for shared helper import
_repo_root = Path(__file__).resolve().parents[3]
_plugin_dir = _repo_root / ".claude-plugin"
if str(_plugin_dir) not in sys.path:
    sys.path.insert(0, str(_plugin_dir))

from lib.local_config_io import find_local_config_file, parse_yaml_file

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
    Uses shared helper from lib.local_config_io for file discovery and parsing.

    Note: This function intentionally does NOT cache results. Server needs fresh
    config on each poll cycle to pick up file changes without restart.

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Tuple of (config_dict, config_path). config_path is None if file not found.

    Raises:
        ValueError: If the config file contains unknown top-level keys or invalid structure.
    """
    # Use shared helper to find config file (no caching)
    config_path = find_local_config_file(start_dir)

    if config_path is None:
        return {}, None

    # Use shared helper to parse YAML
    config = parse_yaml_file(config_path)

    # Validate top-level keys (server-specific validation)
    for key in config:
        if key not in VALID_TOP_LEVEL_KEYS:
            raise ValueError(
                f"Unknown top-level key '{key}' in {config_path}. "
                f"Valid keys: {', '.join(sorted(VALID_TOP_LEVEL_KEYS))}"
            )

    return config, config_path


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
