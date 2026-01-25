# Local Configuration Interface

Loads developer-specific settings from `.agentize.local.yaml` with environment variable override support.

## Purpose

Provides YAML-first configuration for hooks and lib modules, with environment variables as overrides. This enables persistent local settings while maintaining CLI/env flexibility.

## External Interface

### `load_local_config(start_dir: Path | None = None) -> tuple[dict, Path | None]`

Parse `.agentize.local.yaml` by walking parent directories.

**Parameters:**
- `start_dir`: Directory to start searching from (default: current directory)

**Returns:** Tuple of (config_dict, config_path). config_path is None if file not found.

**Search behavior:** Walks up from `start_dir` to parent directories until `.agentize.local.yaml` is found or root is reached.

### `get_local_value(path: str, env: str | None, default: Any, coerce: Callable | None = None) -> Any`

Resolve YAML value by dotted path, apply env override, optional coercion.

**Parameters:**
- `path`: Dotted path to YAML value (e.g., `'handsoff.enabled'`)
- `env`: Environment variable name to check for override (or `None`)
- `default`: Default value if not found in YAML or env
- `coerce`: Optional coercion function (e.g., `coerce_bool`, `coerce_int`)

**Returns:** Resolved value with env override and coercion applied.

**Precedence:** Environment variable > YAML value > default

**Example:**
```python
from lib.local_config import get_local_value, coerce_bool

# Get handsoff.enabled with HANDSOFF_MODE env override
enabled = get_local_value('handsoff.enabled', 'HANDSOFF_MODE', True, coerce_bool)
```

### `coerce_bool(value: Any, default: bool) -> bool`

Coerce value to boolean.

**Accepted values:** `true`, `false`, `1`, `0`, `on`, `off`, `enable`, `disable` (case-insensitive)

**Returns:** Boolean value, or `default` if coercion fails.

### `coerce_int(value: Any, default: int) -> int`

Coerce value to integer.

**Returns:** Integer value, or `default` if coercion fails.

### `coerce_csv_ints(value: Any) -> list[int]`

Parse comma-separated user IDs to list of integers.

**Example:** `"123,456,789"` → `[123, 456, 789]`

**Returns:** List of integers. Empty list on parse error.

## Configuration Schema

```yaml
# .agentize.local.yaml

handsoff:
  enabled: true                    # HANDSOFF_MODE
  max_continuations: 10            # HANDSOFF_MAX_CONTINUATIONS
  auto_permission: true            # HANDSOFF_AUTO_PERMISSION
  debug: false                     # HANDSOFF_DEBUG
  supervisor:
    provider: claude               # HANDSOFF_SUPERVISOR
    model: opus                    # HANDSOFF_SUPERVISOR_MODEL
    flags: ""                      # HANDSOFF_SUPERVISOR_FLAGS

telegram:
  enabled: false                   # AGENTIZE_USE_TG
  token: "..."                     # TG_API_TOKEN
  chat_id: "..."                   # TG_CHAT_ID
  timeout_sec: 60                  # TG_APPROVAL_TIMEOUT_SEC
  poll_interval_sec: 5             # TG_POLL_INTERVAL_SEC
  allowed_user_ids: "123,456"      # TG_ALLOWED_USER_IDS (CSV)

server:
  period: 5m
  num_workers: 5

workflows:
  impl:
    model: opus
  refine:
    model: sonnet
```

## Design Rationale

**Caching:** Config is loaded once per process and cached. This avoids repeated file I/O during permission checks.

**Parent directory search:** Enables running hooks from any subdirectory while finding config at project root.

**Env override:** Environment variables take precedence over YAML, enabling CI/CD and ad-hoc runs without modifying the config file.

**Minimal parser:** Uses the same minimal YAML parser as `runtime_config.py` to avoid external dependencies.

## Internal Usage

- `.claude-plugin/lib/session_utils.py`: `is_handsoff_enabled()` reads `handsoff.enabled`
- `.claude-plugin/lib/logger.py`: Reads `handsoff.debug`
- `.claude-plugin/lib/permission/determine.py`: Reads Telegram and auto-permission settings
- `.claude-plugin/lib/workflow.py`: Reads supervisor config
- `.claude-plugin/hooks/stop.py`: Reads max continuations
