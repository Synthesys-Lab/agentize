# tests/common.sh

Shared test helpers for locating the active worktree, selecting a Python runtime, and providing utilities used across shell-based tests.

## External Interface

### Sourcing

```bash
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"
```

### Environment variables

- `PROJECT_ROOT`: Absolute path to the current git worktree root.
- `AGENTIZE_HOME`: Exported to the current worktree root so tests treat the repo as the framework installation.
- `PYTHON_BIN`: Resolved Python runtime used by test helpers (prefers `python3.11`, then `python3`, then `python`).
- `TESTS_DIR`: Absolute path to the `tests/` directory in the current worktree.

### Helper functions

- `test_pass "message"`: Print a green `PASS:` line and exit `0`.
- `test_fail "message"`: Print a red `FAIL:` line and exit `1`.
- `test_info "message"`: Print a blue `INFO:` line.
- `clean_git_env`: Unset git environment variables that can leak into tests.
- `make_temp_dir "name"`: Create and return a `.tmp/<name>` directory under the project root.
- `cleanup_dir "path"`: Remove a test directory when it exists.
- `python3`: Wrapper that delegates to `PYTHON_BIN` and preserves arguments.

## Internal Helpers

### get_project_root()
Resolves the current worktree root using `git rev-parse --show-toplevel` so tests always target the active repository.

### Python runtime selection
The script resolves `PYTHON_BIN` by checking `python3.11`, then `python3`, then `python`, storing the absolute executable path. Using the full path avoids recursing back into the `python3()` wrapper when the selected runtime is `python3`, while keeping tests compatible with newer typing syntax and older installations.

### Shell portability
Exporting `python3()` is required for subshells that rely on the helper. Since `export -f` is a bash-specific feature, failures are ignored in shells like zsh so the file can be safely sourced in multi-shell test runs.
