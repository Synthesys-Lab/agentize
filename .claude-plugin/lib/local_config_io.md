# Local Config I/O Module

Shared YAML file discovery and parsing helpers for `.agentize.local.yaml`.

## Purpose

Provides a single source of truth for YAML file search order and parsing logic. Both `local_config.py` (hooks) and `runtime_config.py` (server) use these helpers to ensure consistent behavior.

## External Interface

### `find_local_config_file(start_dir: Path | None = None) -> Path | None`

Find `.agentize.local.yaml` using the standard search order.

**Parameters:**
- `start_dir`: Directory to start searching from (default: current directory)

**Returns:** Path to the config file if found, `None` otherwise.

**Search order:**
1. Walk up from `start_dir` to parent directories
2. Check `$AGENTIZE_HOME/.agentize.local.yaml`
3. Check `$HOME/.agentize.local.yaml`

**Note:** This function does NOT cache results. Caching is handled by callers (e.g., `local_config.py` caches for hooks, `runtime_config.py` does not cache for server).

### `parse_yaml_file(path: Path) -> dict`

Parse a YAML file using `yaml.safe_load()`.

**Parameters:**
- `path`: Path to the YAML file

**Returns:** Parsed configuration as nested dict. Returns `{}` on empty content.

## Design Rationale

**Separation of concerns:** File discovery and parsing are pure I/O operations with no caching or validation logic. This allows callers to:
- Add caching (hooks need it, server doesn't)
- Add validation (server validates keys, hooks skip for performance)
- Add coercion (hooks need type coercion helpers)

**Single implementation:** Both modules previously duplicated ~55 lines of identical search logic. Centralizing this eliminates drift and maintenance burden.

**No caching:** Caching is intentionally NOT in this module. The server needs fresh config on each poll cycle, while hooks benefit from caching. Each caller implements the appropriate caching strategy.

## Internal Usage

- `.claude-plugin/lib/local_config.py`: Uses both helpers, wraps with caching
- `python/agentize/server/runtime_config.py`: Uses both helpers, no caching, adds validation
