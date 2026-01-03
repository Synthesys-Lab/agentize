## Test Registration

When adding a new test:

1. Create the test file in `tests/test-<feature>.sh` (all tests live in `tests/` only)
2. Add the test invocation to `tests/test-all.sh`
3. Add the test to `.claude/settings.local.json` allowlist to enable execution without permission prompts:
   ```json
   "Bash(tests/test-<feature>.sh)"
   ```
