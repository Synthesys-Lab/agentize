# tests/common.sh

## Purpose

Shared test helper providing PROJECT_ROOT detection, environment isolation, and reusable utilities for all test scripts.

## Exposed Environment

- `PROJECT_ROOT`: Current worktree root used by tests
- `AGENTIZE_HOME`: Set to `PROJECT_ROOT` for test isolation
- `PYTHON_BIN`: Resolved Python runtime used by tests

## Python Runtime Selection

Prefer `python3` when available; fall back to `python` for portability across developer machines and CI.

The `python3()` wrapper function delegates to `PYTHON_BIN` using the `command` builtin to bypass function lookup and call the binary directly. The wrapper remains local to the test shell to avoid shell-specific export behavior (`export -f` is bash-only).

## Test Result Helpers

- `test_pass "message"`: Print success message and exit 0
- `test_fail "message"`: Print failure message and exit 1
- `test_info "message"`: Print informational message

## Resource Management

- `make_temp_dir "test-name"`: Create a temporary directory under `.tmp/` and return its path
- `cleanup_dir "$TMP_DIR"`: Remove a directory if it exists

## Usage

Source this file at the top of test scripts to ensure consistent setup:

```bash
source "$(dirname "$0")/../common.sh"
```
