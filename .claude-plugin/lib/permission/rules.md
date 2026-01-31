# Permission Rules Module

Defines hardcoded allow/deny/ask rules and merges optional YAML-based rules for tool permission decisions.

## External Interface

### `PERMISSION_RULES`
Dictionary with `allow`, `deny`, and `ask` lists of `(tool, regex)` pairs. Hardcoded deny rules always take precedence over YAML allows.

### `match_rule(tool: str, target: str) -> Optional[tuple]`
Match a tool name and normalized target string against permission rules.

**Parameters:**
- `tool`: Tool name (e.g., `Bash`, `Read`)
- `target`: Normalized target string from the permission parser

**Returns:**
- `(decision, source)` when a rule matches
- `None` when no rule matches

**Decision sources:** `rules:hardcoded`, `rules:project`, `rules:local`, `force-push-verify`

### `clear_yaml_cache() -> None`
Clears the in-memory YAML rules cache to force reloading on the next match. Used by tests.

## Internal Helpers

### `verify_force_push_to_own_branch(command: str) -> Optional[str]`
Checks `git push --force` to issue branches and verifies the current branch name matches the target. Returns `allow`, `deny`, or `None` when not applicable.

### `_find_config_paths(start_dir: Optional[Path]) -> tuple[Optional[Path], Optional[Path]]`
Locates `.agentize.yaml` (project rules) and `.agentize.local.yaml` (local rules) by walking up from `start_dir` and returning the first matches.

### `_parse_yaml_file(path: Path) -> dict`
Parses YAML rules via `yaml.safe_load()`. Returns `{}` when PyYAML is unavailable or when the file is empty.

### `_extract_yaml_rules(config: dict, source: str) -> dict[str, list[tuple[str, str, str]]]`
Normalizes YAML `permissions.allow` / `permissions.deny` entries into `(tool, pattern, source)` tuples.

### `_get_merged_rules(start_dir: Optional[Path]) -> dict[str, list[tuple[str, str, str]]]`
Merges project rules then local rules, caching results by file mtime to avoid repeated parsing.

## Design Rationale

- Hardcoded denies are evaluated first to enforce guardrails for destructive commands.
- YAML rules let teams extend permissions without modifying code.
- Caching minimizes filesystem reads during repeated permission checks.
- When PyYAML is unavailable, YAML rules are skipped so hooks fall back to hardcoded defaults.
