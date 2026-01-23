# Session Utilities Interface

Shared utilities for session directory resolution, handsoff mode checks, and issue index file management used by hooks and lib modules.

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

### `is_handsoff_enabled() -> bool`

Check if handsoff mode is enabled via environment variable.

**Returns:** `True` if handsoff mode is enabled (default), `False` if disabled.

**Behavior:**
- Reads `HANDSOFF_MODE` environment variable
- Returns `False` only when value is `0`, `false`, `off`, or `disable` (case-insensitive)
- Returns `True` for all other values including unset

**Usage:**

```python
from lib.session_utils import is_handsoff_enabled

if not is_handsoff_enabled():
    sys.exit(0)  # Skip hook when handsoff disabled
```

### `write_issue_index(session_id: str, issue_no: int | str, workflow: str, sess_dir: str | None = None) -> str`

Write an issue index file for reverse lookup from issue number to session.

**Parameters:**
- `session_id`: The session ID to index
- `issue_no`: The issue number (int or string)
- `workflow`: The workflow name (e.g., `"issue-to-impl"`)
- `sess_dir`: Optional session directory path. If `None`, uses `session_dir(makedirs=True)`

**Returns:** The path to the created index file

**Behavior:**
- Creates `{sess_dir}/by-issue/{issue_no}.json` with `{"session_id": ..., "workflow": ...}`
- Creates the `by-issue/` subdirectory if it doesn't exist
- Overwrites existing index file for the same issue number

**Usage:**

```python
from lib.session_utils import write_issue_index

# Using default session directory
index_path = write_issue_index(session_id, 42, "issue-to-impl")

# With explicit session directory
index_path = write_issue_index(session_id, issue_no, workflow, sess_dir=custom_dir)
```

## Internal Usage

- `.claude-plugin/hooks/user-prompt-submit.py`: Session tracking, handsoff check, issue index
- `.claude-plugin/hooks/stop.py`: Session cleanup, handsoff check
- `.claude-plugin/hooks/post-bash-issue-create.py`: Issue number persistence, issue index
- `.claude-plugin/lib/logger.py`: Log file path resolution
- `.claude-plugin/lib/permission/determine.py`: Permission decision logging
- `.cursor/hooks/before-prompt-submit.py`: Cursor hook session tracking
- `.cursor/hooks/stop.py`: Cursor hook session cleanup
