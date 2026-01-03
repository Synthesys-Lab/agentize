## Test Registration

When adding a new test:

1. Choose the appropriate category directory:
   - `tests/sdk/` for SDK template tests
   - `tests/cli/` for CLI command tests
   - `tests/lint/` for validation tests
   - `tests/handsoff/` for end-to-end integration tests
2. Create the test file in `tests/<category>/test-<feature>-<case>.sh`
3. Source the shared test helper at the top: `source "$(dirname "$0")/../common.sh"`
4. Source feature-specific helpers if needed: `source "$(dirname "$0")/../helpers-*.sh"`
5. Implement a single test case (one test file = one test case)
6. Tests are automatically discovered by `test-all.sh` (no manual registration required)
7. Add the test to `.claude/settings.local.json` allowlist to enable execution without permission prompts:
   ```json
   "Bash(tests/<category>/test-<feature>-<case>.sh)"
   ```

## Helper Scripts

Helper scripts (`tests/common.sh`, `tests/helpers-*.sh`) are not tests themselves and should NOT be added to `test-all.sh` or executed directly. They provide shared functionality for test scripts:

- `common.sh` - PROJECT_ROOT detection, test result helpers, resource management
- `helpers-worktree.sh` - Worktree test setup/cleanup
- `helpers-gh-mock.sh` - GitHub API mock helpers
- `helpers-makefile-validation.sh` - Makefile validation test helpers
