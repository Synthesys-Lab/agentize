# Agentize Python Package

Python SDK for AI-powered software engineering workflows.

## Structure

```
python/agentize/
├── __init__.py           # Package root
└── permission/           # PreToolUse hook permission module
    ├── __init__.py       # Exports determine()
    ├── determine.py      # Main permission logic
    ├── rules.py          # PERMISSION_RULES and matching
    ├── strips.py         # Bash command normalization
    └── parser.py         # Hook input parsing
```

## Usage

The primary entry point is `agentize.permission.determine()`:

```python
from agentize.permission import determine

# Called from .claude/hooks/pre-tool-use.py
result = determine(sys.stdin.read())
print(json.dumps(result))
```

## Permission Module

The permission module evaluates Claude Code tool use requests and returns allow/deny/ask decisions.

### Decision Flow

1. **Rule Matching** - Check against `PERMISSION_RULES` dict (deny → ask → allow priority)
2. **Haiku LLM** - If no rule matches, ask Haiku for permission (when `HANDSOFF_AUTO_PERMISSION=1`)
3. **Telegram Approval** - For 'ask' decisions, optionally request human approval via Telegram (when `AGENTIZE_USE_TG=1`)

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HANDSOFF_MODE` | Enable hands-off mode (1/true/on) |
| `HANDSOFF_AUTO_PERMISSION` | Enable Haiku-based auto-permission (1/true/on) |
| `HANDSOFF_DEBUG` | Enable debug logging to .tmp/ (1/true/on) |
| `AGENTIZE_USE_TG` | Enable Telegram approval (1/true/on) |
| `TG_API_TOKEN` | Telegram bot API token |
| `TG_CHAT_ID` | Telegram chat ID for approvals |
| `TG_APPROVAL_TIMEOUT_SEC` | Telegram approval timeout (default: 60) |
| `TG_POLL_INTERVAL_SEC` | Telegram polling interval (default: 5) |
| `TG_ALLOWED_USER_IDS` | Comma-separated list of allowed Telegram user IDs |
