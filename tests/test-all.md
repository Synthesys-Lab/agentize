# test-all.sh

Master test runner for Agentize. Auto-discovers `test-*.sh` scripts in the
`tests/` subdirectories and executes them under the configured shells.

## Coverage

- Runs category suites (sdk, cli, lint, e2e) with optional filtering.
- Enforces strict shell availability when `TEST_SHELLS` is explicitly set.
- Skips bash-only hook tests when running in zsh.
