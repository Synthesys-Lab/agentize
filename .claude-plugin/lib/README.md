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

### workflow.py

Unified workflow definitions for handsoff mode. Centralizes workflow detection, issue extraction, and continuation prompts.

**Self-contained design:** This module includes its own `_get_agentize_home()` and `_run_acw()` helpers to invoke the `acw` shell function without importing from `agentize.shell` or depending on `setup.sh`. This maintains plugin standalone capability.

**Usage:**
```python
from lib.workflow import detect_workflow, get_continuation_prompt
```

### logger.py

Debug logging utilities for hooks. Logs permission decisions to `.tmp/hooked-sessions/permission.txt` with unified format when `HANDSOFF_DEBUG` is enabled.

**Usage:**
```python
from lib.logger import logger, log_tool_decision
```

### session_utils.py

Shared session directory path resolution. Returns `.tmp/hooked-sessions` path with optional directory creation.

**Usage:**
```python
from lib.session_utils import session_dir

path = session_dir()              # Get path without creating
path = session_dir(makedirs=True) # Get path and create directories
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
