# Reusable Plugin Libraries

This directory contains all reusable libraries for the Claude Code plugin system.

## Architecture

```
.claude-plugin/
├── lib/                           # All reusable libraries (this directory)
│   ├── __init__.py
│   ├── README.md
│   ├── permission/                # Permission evaluation logic
│   │   ├── __init__.py
│   │   ├── determine.py           # Main permission determination
│   │   ├── rules.py               # Rule matching logic
│   │   ├── parser.py              # Hook input parsing
│   │   └── strips.py              # Command normalization
│   ├── local_config.py            # YAML config loader with caching
│   ├── local_config.md            # Local config documentation
│   ├── local_config_io.py         # Shared YAML file discovery/parsing
│   ├── local_config_io.md         # Shared I/O documentation
│   ├── workflow.py                # Handsoff workflow definitions
│   ├── logger.py                  # Debug logging utilities
│   ├── session_utils.py           # Session directory path resolution
│   ├── session_utils.md           # Session utilities documentation
│   ├── telegram_utils.py          # Telegram Bot API helpers
│   └── telegram_utils.md          # Telegram utilities documentation
├── hooks/                         # Entry points only (import from lib/)
└── ...
```

## Design Principles

**Separation of concerns:**
- `hooks/` = Entry points invoked by Claude Code
- `lib/` = Reusable libraries shared by hooks and server

**Dependency direction:**
- `hooks/` → `lib/`
- `server/` → `lib/`
- `lib/` modules may depend on each other

## Modules

### permission/

Tool permission evaluation for the PreToolUse hook. Provides rule-based matching, Haiku LLM fallback, and Telegram approval integration.

**Entry point:** `from lib.permission import determine`

### local_config.py

Local configuration loader for `.agentize.local.yaml`. Used by hooks to read handsoff, Telegram, and other developer-specific settings.

**YAML search order:**
1. Walk up from current directory to find `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

**Usage:**
```python
from lib.local_config import get_local_value, coerce_bool, coerce_int

# Get handsoff enabled from YAML
enabled = get_local_value('handsoff.enabled', True, coerce_bool)

# Get Telegram token
token = get_local_value('telegram.token', '')
```

See [local_config.md](local_config.md) for details.

### local_config_io.py

Shared YAML file discovery and parsing helpers for `.agentize.local.yaml`. Used by both `local_config.py` (hooks) and server `runtime_config.py` to ensure consistent file lookup behavior.

**Note:** This module does NOT cache results. Caching is handled by callers:
- `local_config.py` caches for hooks (avoid repeated I/O)
- `runtime_config.py` does not cache (server needs fresh config each poll)

**Usage:**
```python
from lib.local_config_io import find_local_config_file, parse_yaml_file

# Find config file using standard search order
config_path = find_local_config_file(start_dir)

# Parse YAML file
config = parse_yaml_file(config_path)
```

See [local_config_io.md](local_config_io.md) for details.

### workflow.py

Unified workflow definitions for handsoff mode. Centralizes workflow detection, issue extraction, and continuation prompts.

**Self-contained design:** This module includes its own `_run_acw()` helper to invoke the `acw` shell function via a local symlink (`lib/acw.sh` → `src/cli/acw.sh`), without importing from `agentize.shell` or depending on `setup.sh`. The symlink is resolved during plugin cache copy per [Claude Code plugin docs](https://code.claude.com/docs/en/plugins-reference#working-with-external-dependencies), making the plugin self-contained at install time.

**Usage:**
```python
from lib.workflow import detect_workflow, get_continuation_prompt
```

### logger.py

Debug logging utilities for hooks. Logs permission decisions to `.tmp/hooked-sessions/permission.txt` with unified format when `HANDSOFF_DEBUG` or `handsoff.debug` is enabled.

**Usage:**
```python
from lib.logger import logger, log_tool_decision
```

### session_utils.py

Shared session utilities for hooks: directory path resolution, handsoff mode checks, and issue index file management.

**Usage:**
```python
from lib.session_utils import session_dir, is_handsoff_enabled, write_issue_index

# Session directory path resolution
path = session_dir()              # Get path without creating
path = session_dir(makedirs=True) # Get path and create directories

# Handsoff mode check (reads from YAML with env override)
if not is_handsoff_enabled():
    sys.exit(0)  # Skip hook when handsoff disabled

# Issue index file creation
write_issue_index(session_id, issue_no, workflow, sess_dir=sess_dir)
```

### telegram_utils.py

Shared Telegram Bot API helpers including HTML escaping and HTTP request handling.

**Usage:**
```python
from lib.telegram_utils import escape_html, telegram_request
```

## Import Patterns

### From hooks (in .claude-plugin/hooks/)

```python
import sys
from pathlib import Path

# Add .claude-plugin to path
plugin_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(plugin_dir))

from lib.permission import determine
from lib.workflow import detect_workflow
from lib.logger import logger
```

### From server (in python/agentize/server/)

```python
import sys
from pathlib import Path

# Add .claude-plugin to path
repo_root = Path(__file__).resolve().parents[3]
plugin_dir = repo_root / ".claude-plugin"
sys.path.insert(0, str(plugin_dir))

from lib.telegram_utils import escape_html, telegram_request
```
