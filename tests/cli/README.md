# CLI Command Tests

## Purpose

Unit tests for command-line interface commands (`wt`, `lol`) validating individual CLI features, argument parsing, and error handling.

## Contents

### Worktree CLI Tests (`test-wt-*`)

Tests for the `wt` (worktree) command:

- `test-wt-bare-repo-required.sh` - Validates worktree commands require bare repo
- `test-wt-clone-basic.sh` - Tests `wt clone` for bare repo creation and initialization
- `test-wt-complete-commands.sh` - Tests shell completion for wt subcommands
- `test-wt-complete-flags.sh` - Tests shell completion for wt flags
- `test-wt-goto.sh` - Tests worktree navigation with `wt goto`
- `test-wt-purge.sh` - Tests cleanup of stale worktrees
- `test-wt-zsh-completion-crash.sh` - Tests zsh completion stability

### Agentize CLI Tests (`test-lol-*`, `test-agentize-*`)

Tests for the `lol` (agentize) command:

- `test-lol-complete-commands.sh` - Tests shell completion for lol subcommands
- `test-lol-complete-flags.sh` - Tests shell completion for lol flags
- `test-lol-help-text.sh` - Validates help text formatting and content
- `test-lol-version.sh` - Tests version command output
- `test-lol-claude-clean.sh` - Tests `lol claude-clean` command for cleaning stale entries
- `test-lol-command-functions-loaded.sh` - Smoke test for `lol_cmd_*` function availability
- `test-agentize-cli-init-*.sh` - Tests for `lol init` command
- `test-agentize-cli-update-*.sh` - Tests for `lol update` command
- `test-agentize-cli-metadata-*.sh` - Tests for metadata-only mode
- `test-agentize-modes-*.sh` - Tests for agentize mode parameter validation

### Other CLI Tests

- `test-install-script.sh` - Tests the one-command installer script
- `test-test-all-strict-shells.sh` - Tests shell compatibility enforcement

## Usage

Run all CLI tests:
```bash
make test-cli
# or
bash tests/test-all.sh --category cli
```

Run a specific CLI test:
```bash
bash tests/cli/test-wt-goto.sh
```

Run CLI tests under multiple shells:
```bash
TEST_SHELLS="bash zsh" bash tests/cli/test-wt-complete-commands.sh
```

## Test Patterns

CLI tests follow the standard test structure:

1. Source `common.sh` for test helpers
2. Set up test environment (temporary directories, mock repositories)
3. Execute CLI command with specific arguments
4. Validate:
   - Exit codes (success/failure)
   - stdout/stderr output
   - File system state changes
   - Error messages
5. Clean up test artifacts

CLI tests are **fast unit tests** focusing on single command behaviors, unlike E2E tests which validate full workflows.

## Related Documentation

- [src/cli/](../../src/cli/) - CLI source implementations
- [tests/e2e/](../e2e/) - End-to-end integration tests
- [tests/README.md](../README.md) - Test suite overview
- [scripts/README.md](../../scripts/README.md) - Script implementations
