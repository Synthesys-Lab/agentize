# Test Registration

## Shell Tests

When adding a new shell test:

1. Choose the appropriate category directory:
   - `tests/sdk/` for SDK template tests
   - `tests/cli/` for CLI command tests
   - `tests/lint/` for validation tests
   - `tests/e2e/` for end-to-end integration tests
2. Create the test file in `tests/<category>/test-<feature>-<case>.sh`
3. Source the shared test helper at the top: `source "$(dirname "$0")/../common.sh"`
4. Source feature-specific helpers if needed: `source "$(dirname "$0")/../helpers-*.sh"`
5. Implement a single test case (one test file = one test case)
6. Tests are automatically discovered by `test-all.sh` (no manual registration required)
7. Add the test to `.claude/settings.local.json` allowlist to enable execution without permission prompts:
   ```json
   "Bash(tests/<category>/test-<feature>-<case>.sh)"
   ```

## Python Tests (pytest)

Python unit tests for server modules and `.claude-plugin/lib` modules live in `python/tests/`:

1. Create test files: `python/tests/test_<module>.py`
2. Tests are automatically discovered by pytest (files matching `test_*.py`)
3. Use `conftest.py` fixtures for path setup (`PROJECT_ROOT`, `PYTHONPATH`, `.claude-plugin` in `sys.path`)
4. Run with: `pytest python/tests` or via `make test`/`make test-fast`
5. For `.claude-plugin/lib` tests, import modules as `from lib.workflow import ...` (`.claude-plugin` is in `sys.path`)

Both `tests/sdk/` and `tests/cli/` are emulating how users would interact with the SDK and CLI.
DO NOT try to modify `setup.sh` or `session-init.sh` to accomodate the test cases.
Instead, modify the CLI and SDK code or tests themselves to pass the tests.

Keep in mind that `AGENTIZE_HOME` is set to point to the current work tree you are testing against!
`PROJECT_ROOT` is set to the root of the repository using agentize CLI to initialize, update, and
develop! **NO TEST** shall modify these two variables using `export`. Just use them as they are.
`PROJECT_ROOT` should be computed using the wrapper in `common.sh`.

If a shell test executes hooks or config discovery that may read `$HOME/.agentize.local.yaml`,
isolate the user home by setting `HOME` to a temp directory inside the test:
```bash
TEST_HOME=$(make_temp_dir "test-home-$$")
export HOME="$TEST_HOME"
trap 'cleanup_dir "$TEST_HOME"' EXIT
```

# Helper Scripts

Helper scripts (`tests/common.sh`, `tests/helpers-*.sh`) are not tests themselves and should NOT be
added to `test-all.sh` or executed directly. They provide shared functionality for test scripts:

- `common.sh` - PROJECT_ROOT detection, test result helpers, resource management
- `helpers-worktree.sh` - Worktree test setup/cleanup
- `helpers-gh-mock.sh` - GitHub API mock helpers
- `helpers-makefile-validation.sh` - Makefile validation test helpers

## Avoiding Embedded Python Blocks

When writing shell tests, avoid embedding `python3 -c` blocks for testing Python logic. Instead:

1. **Test Python logic in pytest**: Add test cases to `python/tests/test_*.py` files
2. **Shell tests for CLI/integration**: Keep shell tests focused on CLI invocation, environment handling, and end-to-end workflows
3. **Benefits**: IDE support, better error messages, reusable fixtures, clearer test organization

**Example - Avoid this in shell tests:**
```bash
# BAD: Embedded Python block
result=$(python3 -c "
def some_function():
    return 'result'
print(some_function())
")
```

**Instead, create a pytest test in `python/tests/`:**
```python
# GOOD: Proper pytest test
def test_some_function():
    from module import some_function
    assert some_function() == 'result'
```
