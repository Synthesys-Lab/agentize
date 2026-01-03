## Test Registration

When adding a new test:

1. Create the test file in `tests/test-<feature>-<case>.sh` (all tests live in `tests/` only)
2. Source the shared test helper at the top: `source "$(dirname "$0")/common.sh"`
3. Implement a single test case (one test file = one test case)
4. Add the test invocation to `tests/test-all.sh` in the appropriate section
5. Add the test to `.claude/settings.local.json` allowlist to enable execution without permission prompts:
   ```json
   "Bash(tests/test-<feature>-<case>.sh)"
   ```

## Helper Scripts

Helper scripts (`tests/common.sh`, `tests/helpers-*.sh`) are not tests themselves and should NOT be added to `test-all.sh` or executed directly. They provide shared functionality for test scripts:

- `common.sh` - PROJECT_ROOT detection, test result helpers, resource management
- `helpers-worktree.sh` - Worktree test setup/cleanup
- `helpers-gh-mock.sh` - GitHub API mock helpers
- `helpers-makefile-validation.sh` - Makefile validation test helpers
