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

**Search behavior:**
1. Walk up from `start_dir` to parent directories until `.agentize.local.yaml` is found
2. If not found, try `$AGENTIZE_HOME/.agentize.local.yaml`
3. If not found, try `$HOME/.agentize.local.yaml`

**Raises:** `ValueError` for unknown top-level keys or invalid structure.

### `resolve_precedence(config_value, default) -> Any`

Return first non-None value in precedence order: config > default.

**Parameters:**
- `config_value`: Value from `.agentize.local.yaml`
- `default`: Default value

**Returns:** First non-None value, or default if config_value is None.

### `extract_workflow_models(config: dict) -> dict[str, str]`

Extract workflow -> model mapping from config.

**Parameters:**
- `config`: Parsed config dict from `load_runtime_config()`

**Returns:** Dict mapping workflow names to model names. Only includes workflows that have a model configured.

**Example:** `{"impl": "opus", "refine": "sonnet"}`

## Shared Helpers (from `lib.local_config_io`)

### `find_local_config_file(start_dir: Path | None) -> Path | None`

Shared YAML file discovery helper used by both server and hooks. Searches for `.agentize.local.yaml` using the standard search order (walk up from start_dir, then `$AGENTIZE_HOME`, then `$HOME`).

**Note:** This function does not cache results. `runtime_config` calls it directly each time to ensure fresh config, while `local_config` wraps it with caching for hooks.

### `parse_yaml_file(path: Path) -> dict`

Shared YAML parsing helper that wraps `yaml.safe_load()`. Returns `{}` on empty content.

## Configuration Schema

```yaml
# .agentize.local.yaml - Developer-specific local configuration

handsoff:
  enabled: true                    # Enable handsoff auto-continuation (default: true)
  max_continuations: 10            # Max auto-continuations per workflow (default: 10)
  auto_permission: true            # Enable Haiku LLM-based auto-permission (default: true)
  debug: false                     # Enable debug logging (default: false)
  supervisor:
    provider: claude               # AI provider (default: none)
    model: opus                    # Model for supervisor
    flags: ""                      # Extra flags for acw

server:
  period: 5m                       # Polling period
  num_workers: 5                   # Worker pool size

telegram:
  enabled: false                   # Enable Telegram approval (default: false)
  token: "..."                     # Bot API token from @BotFather
  chat_id: "..."                   # Chat/channel ID
  timeout_sec: 60                  # Approval timeout (default: 60)
  poll_interval_sec: 5             # Poll interval (default: 5)
  allowed_user_ids: "123,456"      # Allowed user IDs (CSV string)

workflows:
  impl:
    model: opus                    # Model for implementation
  refine:
    model: sonnet                  # Model for refinement
  dev_req:
    model: sonnet                  # Model for dev-req planning
  rebase:
    model: haiku                   # Model for PR rebase
```

**Note:** The `allowed_user_ids` field uses a CSV string format since the minimal YAML parser does not support native arrays.

## Design Rationale

**Precedence order:** config > default ensures:
1. YAML file provides persistent defaults
2. Sensible defaults when nothing is configured

**YAML search order:**
1. Project root `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

This enables user-wide configuration (e.g., Telegram credentials) while allowing project-specific overrides.

**Strict validation:** Raises `ValueError` for unknown keys to catch typos early rather than silently ignoring misconfiguration.

## Parser Capabilities

The PyYAML library provides full YAML 1.2 support including:
- Nested dicts and arrays
- All scalar types (strings, integers, booleans, floats)
- Multi-line literals (`|` and `>`)
- Anchors and aliases
- Flow-style syntax (`[a, b]` and `{a: b}`)

The `permissions` top-level key is allowed for user-configurable permission rules:
```yaml
permissions:
  allow:
    - "^npm run build"
    - pattern: "^cat .*\\.md$"
      tool: Read
  deny:
    - "^rm -rf"
```
