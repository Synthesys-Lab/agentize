# shell.py

Python utilities for invoking shell functions with `AGENTIZE_HOME` set.

## External Interface

### get_agentize_home()

Returns the agentize repository root from the environment or by locating the
project root relative to `python/agentize/shell.py`.

### run_shell_function(cmd, capture_output=False, agentize_home=None)

Runs a shell command via `bash -c` after sourcing `setup.sh`.

**Parameters**:
- `cmd`: Shell command string to run.
- `capture_output`: Whether to capture stdout/stderr in the result.
- `agentize_home`: Optional override for `AGENTIZE_HOME`.

**Returns**:
- `subprocess.CompletedProcess` for the invocation.

## Internal Helpers

Builds the shell command as `source "$AGENTIZE_HOME/setup.sh" && <cmd>` to keep
shell implementations canonical while remaining accessible from Python.
