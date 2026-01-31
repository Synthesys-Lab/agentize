# tests/common.sh

Shared test helpers for locating the active worktree, selecting a Python runtime, and
providing small utilities used across shell-based tests.

## External Interface

### Environment variables
- `AGENTIZE_HOME`: Exported to the current worktree root so tests treat the repo as the
  framework installation.
- `PYTHON_BIN`: Resolved Python runtime used by test helpers (prefers `python3.11`, then
  `python3`, then `python`).
- `TESTS_DIR`: Absolute path to the `tests/` directory in the current worktree.

### Functions

#### `get_project_root()`
Returns the git top-level directory for the current worktree.

#### `python3()`
Wrapper that delegates to `PYTHON_BIN` and preserves the caller's arguments. The
function is exported when supported so subshells can reuse the same runtime choice.

#### `test_pass "message"`
Prints a green success line and exits with status 0.

#### `test_fail "message"`
Prints a red failure line and exits with status 1.

#### `test_info "message"`
Prints a blue informational line and continues execution.

#### `clean_git_env()`
Clears git-related environment variables to keep tests isolated from external git
configuration.

#### `make_temp_dir "test-name"`
Creates and returns a `.tmp/<test-name>` directory under the current worktree.

#### `cleanup_dir "path"`
Removes the provided directory if it exists.

## Internal Helpers

### Python runtime selection
The script resolves `PYTHON_BIN` by checking `python3.11`, then `python3`, then
`python`, storing the absolute executable path. Using the full path avoids
recursing back into the `python3()` wrapper when the selected runtime is
`python3`, while keeping tests compatible with newer typing syntax and older
installations.

### Shell portability
Exporting `python3()` is required for subshells that rely on the helper. Since
`export -f` is a bash-specific feature, failures are ignored in shells like zsh so the
file can be safely sourced in multi-shell test runs.
