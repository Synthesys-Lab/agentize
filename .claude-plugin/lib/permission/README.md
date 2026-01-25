# Permission Module

This module provides the permission determination logic for the PreToolUse hook.

## Purpose

Evaluates tool permission requests using rules, Haiku LLM fallback, and optional Telegram approval integration. Returns `allow`, `deny`, or `ask` decisions for Claude Code tool usage.

## Files

| File | Purpose |
|------|---------|
| `__init__.py` | Exports `determine()` function |
| `determine.py` | Main entry point and orchestration logic |
| `rules.py` | Permission rule definitions and matching |
| `parser.py` | Hook input parsing and target extraction |
| `strips.py` | Bash command normalization (env vars, shell prefixes) |

## Integration

Called by `.claude/hooks/pre-tool-use.py` which is a thin wrapper:

```python
from agentize.permission import determine
result = determine(sys.stdin.read())
```

## Rule Sources

Permission rules come from multiple sources, evaluated in this order:

1. **Hardcoded rules** (`rules.py`) - Built-in rules in `PERMISSION_RULES` dict. Deny rules here always win.
2. **Project rules** (`.agentize.yaml`) - Team-shared rules under `permissions.allow` and `permissions.deny`
3. **Local rules** (`.agentize.local.yaml`) - Developer-specific rules under `permissions.allow` and `permissions.deny`

YAML rules use arrays of strings or dicts:
- String: `"^pattern"` → matches Bash tool by default
- Dict: `{pattern: "^pattern", tool: "Read"}` → explicit tool

See `.claude/hooks/pre-tool-use.md` for rule syntax and `docs/feat/permissions/rules.md` for full details.
