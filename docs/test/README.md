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

## Test Runners

Agentize uses two test frameworks:

1. **Shell tests** (`tests/`): CLI and SDK integration tests using bash/zsh
2. **Pytest** (`python/tests/`): Python module unit tests for server components

### Shell Test Runner

The shell test suite supports running tests under multiple shells to ensure shell-neutral compatibility:

- **Default behavior**: Tests run under bash via `make test`
- **Multi-shell testing**: Tests can run under bash and zsh via `make test-shells` or `TEST_SHELLS="bash zsh" ./tests/test-all.sh`
- **Shell availability**: When `TEST_SHELLS` is explicitly set, all listed shells must be available or the test runner exits with an error. This ensures CI enforcement catches missing shell installations.
- **CI enforcement**: GitHub Actions runs `make test-shells` on every push/PR with zsh installed, ensuring bash+zsh compatibility is maintained.

This enables early detection of shell-specific issues (e.g., bashisms) before users encounter them in different shell environments.

### Pytest Runner

Python tests for server modules and `.claude-plugin/lib` modules live in `python/tests/` and run via pytest:

- Tests are automatically discovered by pytest (files matching `test_*.py`)
- Both `make test` and `make test-fast` run pytest after shell tests
- To run pytest only: `pytest python/tests`
- Install dev dependencies: `python -m pip install -r python/requirements-dev.txt`
- The `.claude-plugin` directory is added to `sys.path` via `conftest.py` to enable testing plugin modules

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

Shell tests are executed via `tests/test-all.sh`, which automatically discovers tests in categorical subdirectories. Python tests run via pytest. The commands documented in `docs/architecture/architecture.md`:

- `make test` - Run all tests (shell tests under bash + pytest)
- `make test-shells` - Run all tests under bash and zsh (fails if zsh not installed)
- `make test-sdk` - Run SDK template tests
- `make test-cli` - Run CLI command tests
- `make test-lint` - Run validation tests
- `make test-e2e` - Run end-to-end integration tests
- `make test-fast` - Run fast tests (sdk + cli + lint + pytest)

**Note**: When `TEST_SHELLS` is explicitly set (e.g., via `make test-shells`), the test runner enforces strict shell availability and exits with an error if any required shell is missing.

## Integration

Testing documentation is referenced from:
- Main [README.md](../README.md) under "Testing Documentation"
- Workflows in [docs/feat/core/](../feat/core/)
- Individual skill and command implementations
