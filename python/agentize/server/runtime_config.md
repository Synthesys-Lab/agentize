# Runtime Configuration Module

Handles loading server-specific settings from `.agentize.local.yaml`.

## Purpose

Separates runtime configuration (credentials, machine-specific tuning) from project metadata (`.agentize.yaml`). This file should not be committed as it contains deployment-specific settings.

## External Interface

### `load_runtime_config(start_dir: Path | None = None) -> tuple[dict, Path | None]`

Load runtime configuration from `.agentize.local.yaml`.

**Parameters:**
- `start_dir`: Directory to start searching from (default: current directory)

**Returns:** Tuple of (config_dict, config_path). config_path is None if file not found.

**Search behavior:** Walks up from `start_dir` to parent directories until `.agentize.local.yaml` is found or root is reached.

**Raises:** `ValueError` for unknown top-level keys or invalid structure.

### `resolve_precedence(cli_value, env_value, config_value, default) -> Any`

Return first non-None value in precedence order: CLI > env > config > default.

**Parameters:**
- `cli_value`: Value from CLI argument
- `env_value`: Value from environment variable
- `config_value`: Value from `.agentize.local.yaml`
- `default`: Default value

**Returns:** First non-None value, or default if all are None.

### `extract_workflow_models(config: dict) -> dict[str, str]`

Extract workflow -> model mapping from config.

**Parameters:**
- `config`: Parsed config dict from `load_runtime_config()`

**Returns:** Dict mapping workflow names to model names. Only includes workflows that have a model configured.

**Example:** `{"impl": "opus", "refine": "sonnet"}`

## Internal Helpers

### `_parse_yaml_file(path: Path) -> dict`

Parse a simple YAML file into a nested dict. Supports basic YAML structure with nested dicts. Does not support arrays, anchors, or complex YAML features.

This minimal parser avoids external dependencies, consistent with the project's approach for `.agentize.yaml` parsing.

## Configuration Schema

```yaml
server:
  period: 5m         # Polling period
  num_workers: 5     # Worker pool size

telegram:
  token: "..."       # Bot API token
  chat_id: "..."     # Chat ID

workflows:
  impl:
    model: opus      # Model for implementation
  refine:
    model: sonnet    # Model for refinement
  dev_req:
    model: sonnet    # Model for dev-req planning
  rebase:
    model: haiku     # Model for PR rebase
```

## Design Rationale

**Precedence order:** CLI > env > config > default ensures:
1. Operators can override config via CLI for ad-hoc runs
2. Environment variables provide deployment flexibility (esp. for Telegram credentials)
3. Config file provides persistent defaults
4. Sensible defaults when nothing is configured

**Parent directory search:** Allows running server from any subdirectory while finding config at project root.

**Strict validation:** Raises `ValueError` for unknown keys to catch typos early rather than silently ignoring misconfiguration.
