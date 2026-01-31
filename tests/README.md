# Tests Directory

This directory contains test suites for validating Agentize SDK functionality and commands.

## Purpose

Automated test scripts verify that SDK templates, CLI tools, and infrastructure components work correctly across different programming languages and environments.

## Test Organization

### Test Infrastructure

- `test-all.sh` - Master test runner that executes all test suites and reports summary
- `common.sh` - Shared test setup helpers (project root detection, output helpers, temp dirs)
- `helpers-worktree.sh` - Shared worktree test setup/cleanup helpers
- `helpers-gh-mock.sh` - Shared gh mock helpers for issue/PR tests
- `helpers-makefile-validation.sh` - Shared helpers for makefile validation tests

### Test Organization Pattern

Each test script follows the naming pattern `test-<feature>-<case>.sh` and represents a **single test case**. Each test sources a small shared setup block from `tests/common.sh` (project root detection, helper functions) to keep shell-neutral compatibility.

Test files are organized into categorical subdirectories:
- **`tests/sdk/`** - SDK template tests (fast unit tests for SDK generation)
- **`tests/cli/`** - CLI command and tool tests (unit tests for CLI tools)
- **`tests/lint/`** - Validation and linting tests (static checks and makefile validation)
- **`tests/e2e/`** - End-to-end integration tests (slower tests with full workflows)

### Test Fixtures

- `fixtures/` - Test data and mock files used by tests

## Running Tests

Run all tests (bash only):
```bash
make test
# or
bash tests/test-all.sh
```

Run all tests under multiple shells (bash and zsh):
```bash
make test-shells
# or
TEST_SHELLS="bash zsh" tests/test-all.sh
```

Run tests by category:
```bash
make test-sdk        # Fast SDK unit tests
make test-cli        # CLI tool tests
make test-lint       # Validation and linting tests
make test-e2e        # End-to-end integration tests
make test-fast       # Alias for sdk + cli + lint
```

Run a specific test suite:
```bash
bash tests/sdk/test-c-sdk.sh
bash tests/e2e/test-worktree.sh
```

Run a specific test under zsh:
```bash
zsh tests/sdk/test-c-sdk.sh
```

## Test Structure

Each test script represents a single test case and follows this pattern:

1. Source the shared test setup block (`tests/common.sh`)
2. Set up test environment (temporary directories via `make_temp_dir`)
3. Execute the functionality being tested
4. Validate expected outcomes (using `test_pass` or `test_fail`)
5. Clean up test artifacts (using `cleanup_dir` or implicit cleanup)
6. Exit with status code (0 = pass, 1 = fail)

The shared setup block provides:
- `PROJECT_ROOT` and `TESTS_DIR` variables
- Color constants for terminal output
- Test result helpers: `test_pass`, `test_fail`, `test_info`
- Resource management: `make_temp_dir`, `cleanup_dir`

## Adding New Tests

### Shell Tests

All shell tests must live in a categorized subdirectory under `tests/`. Do not create tests under `.claude/*/tests/` or other locations.

1. Choose the appropriate category directory:
   - `tests/sdk/` for SDK template tests
   - `tests/cli/` for CLI command tests
   - `tests/lint/` for validation tests
   - `tests/e2e/` for end-to-end integration tests
2. Create a new test script: `tests/<category>/test-<feature>-<case>.sh`
3. Resolve the test script directory and source the shared helpers:

```bash
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"
```
4. Source feature-specific helpers if needed: `source "$(dirname "$0")/../helpers-*.sh"`
5. Implement a single test case with clear assertions
6. Use the inlined helper functions or feature-specific helpers
7. The test will be automatically discovered by `test-all.sh` (no manual registration required)
8. Update `.claude/settings.local.json` to allow execution without permission prompts (see `tests/CLAUDE.md`)

### Python Tests (pytest)

Python unit tests for server modules live in `python/tests/`:

1. Create test files: `python/tests/test_<module>.py`
2. Tests are automatically discovered by pytest (files matching `test_*.py`)
3. Use `conftest.py` fixtures for path setup (`PROJECT_ROOT`, `PYTHONPATH`)
4. Use `unittest.mock` for mocking subprocess calls and external dependencies
5. Run with: `pytest python/tests` or via `make test`/`make test-fast`

## Integration

Test documentation is tracked in:
- [docs/test/workflow.md](../docs/test/workflow.md) - Dogfooding validation status
- [docs/test/agents.md](../docs/test/agents.md) - Agent infrastructure test coverage
