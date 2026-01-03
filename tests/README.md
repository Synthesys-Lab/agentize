# Tests Directory

This directory contains test suites for validating Agentize SDK functionality and commands.

## Purpose

Automated test scripts verify that SDK templates, CLI tools, and infrastructure components work correctly across different programming languages and environments.

## Test Organization

### Test Runner

- `test-all.sh` - Master test runner that executes all test suites and reports summary

### SDK Template Tests

- `test-c-sdk.sh` - C SDK template validation
- `test-cxx-sdk.sh` - C++ SDK template validation
- `test-python-sdk.sh` - Python SDK template validation

### CLI and Infrastructure Tests

- `test-agentize-cli.sh` - Agentize CLI function validation
- `test-agentize-modes.sh` - Mode validation (init/update) tests
- `test-worktree.sh` - Worktree functionality tests
- `test-wt-cross-project.sh` - Cross-project wt function tests

### Validation Tests

- `test-makefile-validation.sh` - Makefile parameter validation logic tests
- `test-claude-permission-hook.sh` - Claude Code permission hook tests

### Commands & Skills Tests

- `test-refine-issue.sh` - `/refine-issue` command workflow tests
- `test-open-issue-draft.sh` - `/open-issue` skill draft prefix tests

### Test Fixtures

- `fixtures/` - Test data and mock files for permission request tests

## Running Tests

Run all tests:
```bash
make test
# or
bash tests/test-all.sh
```

Run a specific test suite:
```bash
bash tests/test-c-sdk.sh
bash tests/test-worktree.sh
```

## Test Structure

Each test script follows this pattern:
1. Set up test environment (temporary directories, fixtures)
2. Execute the functionality being tested
3. Validate expected outcomes
4. Clean up test artifacts
5. Exit with status code (0 = pass, 1 = fail)

## Adding New Tests

All tests must live in the `tests/` directory. Do not create tests under `.claude/*/tests/` or other locations.

1. Create a new test script: `tests/test-<feature>.sh`
2. Add inline documentation using comments:
   ```bash
   # Test 1: Description of what is being tested
   # Expected: What should happen
   ```
3. Add the test to `test-all.sh`
4. Update `.claude/settings.local.json` to allow execution without permission prompts (see `tests/CLAUDE.md`)

## Integration

Test documentation is tracked in:
- [docs/test/workflow.md](../docs/test/workflow.md) - Dogfooding validation status
- [docs/test/agents.md](../docs/test/agents.md) - Agent infrastructure test coverage
