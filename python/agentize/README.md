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
├── workflow/             # Python planner + impl workflow orchestration
│   └── impl/             # Issue-to-implementation workflow (lol impl)
└── server/               # Polling server module
    └── __main__.py       # Server entry point (python -m agentize.server)
```

**Note**: Shared utilities (permission, workflow, telegram_utils, logger) have been consolidated into `.claude-plugin/lib/`. See [.claude-plugin/lib/README.md](../../.claude-plugin/lib/README.md) for details.

## Usage

### CLI Entrypoint

```bash
python -m agentize.cli <command> [options]
```

The Python CLI delegates to shell functions for most commands via the shared `shell.py` module with `AGENTIZE_HOME` set. The `impl` command runs the Python workflow implementation. See `cli.md` for interface details.

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

The permission module has been moved to `.claude-plugin/lib/permission/`. See the lib README for usage:

```python
# Import from lib (after adding .claude-plugin to sys.path)
from lib.permission import determine
```

## Server Module

The server module (`python -m agentize.server`) imports shared utilities from `.claude-plugin/lib/` for Telegram notifications.
