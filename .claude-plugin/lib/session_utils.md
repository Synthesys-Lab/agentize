# Session Utilities Interface

Shared utilities for session directory path resolution used by hooks and lib modules.

## External Interface

### `session_dir(makedirs: bool = False) -> str`

Get the session directory path using `AGENTIZE_HOME` fallback.

**Parameters:**
- `makedirs`: If `True`, create the directory structure if it doesn't exist (default: `False`)

**Returns:** String path to the session directory (`.tmp/hooked-sessions` under the base directory)

**Behavior:**
- Uses `AGENTIZE_HOME` environment variable as base path, defaults to `.` (current directory)
- Returns `{base}/.tmp/hooked-sessions`
- When `makedirs=True`, creates both the base and session directories
- Always returns a string type (not `Path` object) for compatibility

**Usage:**

```python
from lib.session_utils import session_dir

# Get path without creating directories (default)
path = session_dir()
# Returns: "./.tmp/hooked-sessions" or "{AGENTIZE_HOME}/.tmp/hooked-sessions"

# Get path and create directories if needed
path = session_dir(makedirs=True)
# Creates directories and returns path
```

## Internal Usage

- `.claude-plugin/hooks/user-prompt-submit.py`: Session tracking for handsoff mode
- `.claude-plugin/hooks/stop.py`: Session cleanup on stop
- `.claude-plugin/hooks/post-bash-issue-create.py`: Issue number persistence
- `.claude-plugin/lib/logger.py`: Log file path resolution
- `.claude-plugin/lib/permission/determine.py`: Permission decision logging
- `.cursor/hooks/before-prompt-submit.py`: Cursor hook session tracking
- `.cursor/hooks/stop.py`: Cursor hook session cleanup
