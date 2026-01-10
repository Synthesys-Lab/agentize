# Agentize Python Package

Python SDK for AI-powered software engineering workflows.

## Structure

```
python/agentize/
├── __init__.py           # Package root
├── cli.py                # Python CLI entrypoint (python -m agentize.cli)
├── cli.md                # CLI interface documentation
├── shell.py              # Shared shell function invocation utilities
├── usage.py              # Claude Code token usage statistics
├── telegram_utils.py     # Shared Telegram API utilities
├── telegram_utils.md     # Telegram utilities interface documentation
├── server/               # Polling server module
│   └── __main__.py       # Server entry point (python -m agentize.server)
└── permission/           # PreToolUse hook permission module
    ├── __init__.py       # Exports determine()
    ├── determine.py      # Main permission logic
    ├── rules.py          # PERMISSION_RULES and matching
    ├── strips.py         # Bash command normalization
    └── parser.py         # Hook input parsing
```

## Usage

### CLI Entrypoint

```bash
python -m agentize.cli <command> [options]
```

The Python CLI delegates to shell functions via the shared `shell.py` module with `AGENTIZE_HOME` set. It provides argparse-style parsing while preserving shell as the canonical implementation. See `cli.md` for interface details.

### Shell Utilities

```python
from agentize.shell import get_agentize_home, run_shell_function

# Auto-detect AGENTIZE_HOME
home = get_agentize_home()

# Run shell functions with AGENTIZE_HOME set
result = run_shell_function("wt spawn 123", capture_output=True)
print(result.returncode, result.stdout)
```

The `shell.py` module provides a unified interface for invoking shell functions from Python. It handles `AGENTIZE_HOME` auto-detection and sources `setup.sh` before running commands.

### Permission Module

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

### Test Isolation

Tests automatically clear Telegram-related environment variables (`AGENTIZE_USE_TG`, `TG_API_TOKEN`, `TG_CHAT_ID`, `TG_ALLOWED_USER_IDS`, `TG_APPROVAL_TIMEOUT_SEC`, `TG_POLL_INTERVAL_SEC`) via `tests/common.sh` to prevent external API calls during test runs. The Telegram API request functions also include an internal guard that returns `None` immediately when Telegram is disabled.
