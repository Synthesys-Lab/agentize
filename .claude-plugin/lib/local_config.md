# Local Configuration Interface

Loads developer-specific settings from `.agentize.local.yaml`.

## Purpose

Provides YAML-only configuration for hooks and lib modules. This enables persistent local settings with a simple, unified configuration source.

## YAML Search Order

1. Walk up from current directory to find `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

## External Interface

### `load_local_config(start_dir: Path | None = None) -> tuple[dict, Path | None]`

Parse `.agentize.local.yaml` using the YAML search order.

**Parameters:**
- `start_dir`: Directory to start searching from (default: current directory)

**Returns:** Tuple of (config_dict, config_path). config_path is None if file not found.

**Search behavior:** Walks up from `start_dir` to parent directories, then falls back to `$AGENTIZE_HOME` and `$HOME`.

### `get_local_value(path: str, default: Any, coerce: Callable | None = None) -> Any`

Resolve YAML value by dotted path with optional coercion.

**Parameters:**
- `path`: Dotted path to YAML value (e.g., `'handsoff.enabled'`)
- `default`: Default value if not found in YAML
- `coerce`: Optional coercion function (e.g., `coerce_bool`, `coerce_int`)

**Returns:** Resolved value with coercion applied.

**Precedence:** YAML value > default

**Example:**
```python
from lib.local_config import get_local_value, coerce_bool

# Get handsoff.enabled from YAML
enabled = get_local_value('handsoff.enabled', True, coerce_bool)
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
  enabled: true
  max_continuations: 10
  auto_permission: true
  debug: false
  supervisor:
    provider: claude
    model: opus
    flags: ""

telegram:
  enabled: false
  token: "..."
  chat_id: "..."
  timeout_sec: 60
  poll_interval_sec: 5
  allowed_user_ids: "123,456"

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

**YAML search order:** Enables running hooks from any subdirectory while finding config at project root, with fallback to user-wide settings at `$HOME`.

**No environment overrides:** YAML is the sole configuration source, providing a single, predictable place to manage settings.

**PyYAML library:** Uses `yaml.safe_load()` for full YAML 1.2 compliance, providing robust parsing with support for all standard YAML features.

## Internal Usage

- `.claude-plugin/lib/session_utils.py`: `is_handsoff_enabled()` reads `handsoff.enabled`
- `.claude-plugin/lib/logger.py`: Reads `handsoff.debug`
- `.claude-plugin/lib/permission/determine.py`: Reads Telegram and auto-permission settings
- `.claude-plugin/lib/workflow.py`: Reads supervisor config
- `.claude-plugin/hooks/stop.py`: Reads max continuations
