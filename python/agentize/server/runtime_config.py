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

import yaml

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
    """Parse YAML file using PyYAML's safe_load.

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict
    """
    with open(path, "r") as f:
        return yaml.safe_load(f) or {}


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
