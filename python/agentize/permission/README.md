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

## Rule Source

Permission rules are defined in `rules.py` as Python tuples in `PERMISSION_RULES`. This is the canonical location for all permission rules.

See `.claude/hooks/pre-tool-use.md` for rule syntax and interface details.
