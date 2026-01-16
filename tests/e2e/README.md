# End-to-End Integration Tests

## Purpose

End-to-end integration tests validating complete workflows and multi-component interactions across the agentize framework.

## Contents

### Worktree E2E Tests (`test-wt-cross-*`, `test-worktree-*`)

Full workflow tests for worktree management:

- `test-wt-cross-init-creates-main.sh` - Tests `wt init` creates main worktree
- `test-wt-cross-spawn-from-linked.sh` - Tests spawning worktree from linked repo
- `test-wt-cross-invalid-agentize-home.sh` - Tests behavior with invalid AGENTIZE_HOME
- `test-wt-cross-missing-agentize-home.sh` - Tests behavior without AGENTIZE_HOME
- `test-worktree-flag-order-after-issue.sh` - Placeholder for flag parsing edge cases
- `test-worktree-reject-description-arg.sh` - Placeholder for argument validation edge cases
- `test-worktree-spawn-yolo-no-agent.sh` - Placeholder for agent-free spawn edge cases

### Project Automation E2E Tests (`test-lol-project-*`, `test-setup-viewboard-*`)

GitHub Projects integration workflows:

- `test-lol-project-create.sh` - Tests project creation via `lol project create`
- `test-lol-project-create-user.sh` - Tests project creation for user-owned projects
- `test-lol-project-associate.sh` - Tests associating issues with projects
- `test-lol-project-auto-field.sh` - Tests automatic field population
- `test-lol-project-automation.sh` - Tests project automation workflows
- `test-lol-project-automation-write.sh` - Tests writing automation configurations
- `test-lol-project-help.sh` - Tests project command help text
- `test-lol-project-metadata-preservation.sh` - Tests metadata persistence
- `test-lol-project-missing-metadata.sh` - Tests behavior without metadata
- `test-lol-project-status-missing.sh` - Tests Status field verification auto-creates missing options

### Issue Management E2E Tests (`test-open-issue-*`)

Issue creation and update workflows:

- `test-open-issue-with-draft.sh` - Tests creating issues from draft files
- `test-open-issue-without-draft.sh` - Tests creating issues without drafts
- `test-open-issue-draft-non-plan.sh` - Tests non-plan issue creation
- `test-open-issue-update-mode.sh` - Tests updating existing issues
- `test-open-issue-update-maintains-format.sh` - Tests format preservation during updates

### Multi-Agent E2E Tests (`test-external-consensus-*`)

Multi-agent debate and consensus workflows:

- `test-external-consensus-issue-interface.sh` - Tests consensus-based issue creation interface

### Linter E2E Tests

- `test-lint-documentation.sh` - Tests documentation linter in realistic scenarios

## Usage

Run all E2E tests:
```bash
make test-e2e
# or
bash tests/test-all.sh --category e2e
```

Run a specific E2E test:
```bash
bash tests/e2e/test-wt-cross-spawn-from-linked.sh
```

Run E2E tests under multiple shells:
```bash
TEST_SHELLS="bash zsh" bash tests/e2e/test-lol-project-create.sh
```

## Test Characteristics

E2E tests differ from unit tests:

- **Slower execution**: Full workflow validation, multi-step operations
- **Complex setup**: May create temporary repos, mock GitHub CLI, set up worktrees
- **Multi-component**: Tests interactions between CLI, scripts, and external tools
- **Realistic scenarios**: Simulates actual user workflows end-to-end

E2E tests use helpers from `tests/helpers-*.sh` for common setup/teardown patterns.

## Test Fixtures

E2E tests may use fixtures from `tests/fixtures/` for:
- Mock GitHub API responses
- Sample project structures
- Configuration templates

## Related Documentation

- [tests/cli/](../cli/) - CLI unit tests (faster, single-command focus)
- [tests/fixtures/](../fixtures/) - Test fixtures and mock data
- [tests/helpers-worktree.sh](../helpers-worktree.sh) - Worktree test helpers
- [tests/README.md](../README.md) - Test suite overview
