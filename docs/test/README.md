# Testing Documentation

This directory contains documentation about testing strategies, validation workflows, and agent testing for Agentize.

## Purpose

These documents track testing status, define test strategies, and document validation approaches for AI-powered components. Since AI rules are subjective and LLM-dependent, this documentation emphasizes dogfooding (using Agentize to develop itself) as the primary validation method.

## Files

### workflow.md
Testing and dogfooding status tracker. Documents the validation status of all skills, commands, and agents, with real-world usage examples and maturity indicators (✅ Validated, 🔄 In Progress, ⚠️ Partial, ❌ Untested, 🔧 Needs Revision).

### agents.md
Agent infrastructure test coverage. Defines test cases for the `.claude/agents/` directory, agent discovery, directory structure validation, and dogfooding validation criteria.

### code-review-agent.md
Code review agent test coverage. Documents test cases for the code-review agent functionality, review standards enforcement, and integration with the review workflow.

## Testing Philosophy

Agentize follows a **dogfooding-first** testing approach:
- AI rules are tested by using them to develop Agentize itself
- Real-world usage provides the most realistic validation
- Traditional unit tests complement but don't replace dogfooding
- Validation status is tracked and documented for transparency

## Shell Test Runner

The shell test suite supports running tests under multiple shells to ensure shell-neutral compatibility:

- **Default behavior**: Tests run under bash via `make test`
- **Multi-shell testing**: Tests can run under bash and zsh via `make test-shells` or `TEST_SHELLS="bash zsh" ./tests/test-all.sh`
- **Shell availability**: Missing shells are skipped with a warning; bash is always the default

This enables early detection of shell-specific issues (e.g., bashisms) before users encounter them in different shell environments.

## Test Structure

Each test script represents a **single test case** and follows this pattern:

1. Source the shared test helper: `source "$(dirname "$0")/common.sh"`
2. Set up test environment (temporary directories via `make_temp_dir`)
3. Execute the functionality being tested
4. Validate expected outcomes (using `test_pass` or `test_fail`)
5. Clean up test artifacts (using `cleanup_dir` or implicit cleanup)
6. Exit with status code (0 = pass, 1 = fail)

The shared helper `tests/common.sh` provides:
- `PROJECT_ROOT` and `TESTS_DIR` variables
- Color constants for terminal output
- Test result helpers: `test_pass`, `test_fail`, `test_info`
- Resource management: `make_temp_dir`, `cleanup_dir`

## Running Tests

All tests are executed via `tests/test-all.sh`, which maintains an explicit list of test files. The commands documented in `docs/architecture/architecture.md` remain unchanged:

- `make test` - Run all tests under bash
- `make test-shells` - Run all tests under bash and zsh

## Integration

Testing documentation is referenced from:
- Main [README.md](../README.md) under "Testing Documentation"
- Workflows in [docs/workflows/](../workflows/)
- Individual skill and command implementations
