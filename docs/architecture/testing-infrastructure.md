# Testing Infrastructure

## Overview

The Agentize test suite validates that the installation script (`scripts/install.sh`) works correctly across different modes and language templates. The suite automates the testing procedures documented in README.md, ensuring reproducibility and enabling CI/CD integration.

### Purpose

- **Verify installation correctness**: Ensure `make agentize` creates expected files and directories
- **Prevent regressions**: Catch breaking changes to install.sh or templates
- **Enable CI/CD**: Provide automated testing for continuous integration
- **Support multiple modes**: Test init mode, port mode, and multi-language projects

### Scope

What we test:
- Init mode creates full project structure (`.claude/`, `Makefile`, `README.md`, etc.)
- Port mode creates only `.claude/` without modifying existing files
- Language templates generate correct files (Python, C++, C, Rust)
- Multi-language projects combine templates correctly
- Generated Makefiles have proper test targets

What we **don't** test:
- Whether generated projects build successfully (that's for generated project tests)
- SDK's own code quality (that's for code review)
- Performance of installation (functional correctness only)

## Architecture

### Directory Structure

```
tests/
├── run-all.sh              # Main test runner (entry point)
├── test-init-mode.sh       # Tests for init mode installation
├── test-port-mode.sh       # Tests for port mode installation
├── test-languages.sh       # Tests for language template generation
└── lib/
    ├── assertions.sh       # Assertion library (assert_file_exists, etc.)
    └── test-utils.sh       # Setup/teardown utilities (create_test_dir, etc.)
```

### Component Responsibilities

| Component | Responsibility | Key Functions |
|-----------|---------------|---------------|
| `run-all.sh` | Test orchestration | Discover tests, run all, report summary |
| `test-*.sh` | Individual test suites | Test specific installation modes |
| `lib/assertions.sh` | Verification helpers | Provide assertion functions |
| `lib/test-utils.sh` | Test infrastructure | Create temp dirs, run agentize, cleanup |

### Test Runner Design (`run-all.sh`)

**Responsibilities**:
1. Discover all test scripts (`test-*.sh`)
2. Execute each test in sequence
3. Track pass/fail counts
4. Report summary
5. Return exit code: 0 = all pass, non-zero = any failure

**Discovery mechanism**:
- Explicit list of test scripts (not glob-based)
- Ensures deterministic execution order
- Easy to add new tests

**Exit code handling**:
- Each test script returns 0 on success, non-zero on failure
- Runner accumulates failures
- Final exit code indicates overall success/failure (CI-friendly)

**Output format**:
```
Running Agentize tests...

[PASS] test-init-mode.sh
[PASS] test-port-mode.sh
[FAIL] test-languages.sh

Summary: 2 passed, 1 failed
```

### Assertion Library (`lib/assertions.sh`)

**Design philosophy**:
- Simple, readable assertion functions
- Descriptive error messages
- No dependencies beyond standard Unix tools
- Fail-fast on first assertion failure

**Available assertions**:

```bash
assert_file_exists <path>
# Verify file exists at path. Fails test if not found.
# Example: assert_file_exists "$TEST_DIR/.claude/CLAUDE.md"

assert_dir_exists <path>
# Verify directory exists at path. Fails test if not found.
# Example: assert_dir_exists "$TEST_DIR/.claude/agents"

assert_file_contains <path> <pattern>
# Verify file contains pattern (grep regex). Fails if pattern not found.
# Example: assert_file_contains "$TEST_DIR/Makefile" "build-python"

assert_command_succeeds <command>
# Run command and verify exit code 0. Fails on non-zero exit.
# Example: assert_command_succeeds "make -C $TEST_DIR build"

fail <message>
# Explicitly fail test with custom message.
# Example: fail "Expected 13 files in agents/ but found $count"
```

**Implementation pattern**:
- Each assertion uses `test` (`[`) for checks
- Prints descriptive error message on failure
- Exits with non-zero code to fail the test

### Test Utilities (`lib/test-utils.sh`)

**Responsibilities**:
- Create isolated test environments
- Execute `make agentize` with proper parameters
- Clean up temporary resources

**Available functions**:

```bash
create_test_dir <name_suffix>
# Create unique temporary directory for test isolation
# Returns: /tmp/agentize-test-<name_suffix>-<random>
# Example:
#   test_dir=$(create_test_dir "init")
#   # Returns: /tmp/agentize-test-init-abc123

cleanup_test_dir <path>
# Remove temporary directory created by create_test_dir
# Safe to call multiple times (idempotent)
# Uses trap to ensure cleanup even on test failure
# Example:
#   cleanup_test_dir "$test_dir"

run_agentize <target_dir> <project_name> <mode> [lang] [impl_dir]
# Execute make agentize with given parameters
# Wrapper around: make agentize AGENTIZE_MASTER_PROJ=<target> ...
# Example:
#   run_agentize "$test_dir" "TestProject" "init" "python" "lib"
```

## Test Isolation Strategy

### Temporary Directory Usage

**Goal**: Each test runs in a completely clean environment with no side effects.

**Implementation**:
- Use `mktemp -d` to create unique temporary directories
- Pattern: `/tmp/agentize-test-<test-name>-XXXXXX`
- Each test gets its own directory to avoid conflicts
- Directories are automatically unique even if tests run in parallel (future)

**Benefits**:
- No test pollution: Each test starts fresh
- Parallel-safe: No conflicts between concurrent tests
- Debugging-friendly: Temp dirs can be preserved on failure

### Cleanup Mechanisms

**Automatic cleanup**:
```bash
# In test-utils.sh
create_test_dir() {
    local name=$1
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/agentize-test-${name}-XXXXXX")

    # Set up automatic cleanup on exit
    trap "rm -rf '$temp_dir'" EXIT INT TERM

    echo "$temp_dir"
}
```

**Manual cleanup**:
- Root Makefile provides `make clean` that removes `/tmp/agentize-test-*`
- Test runner can preserve directories on failure for debugging (future enhancement)

**Cleanup guarantees**:
- `trap` ensures cleanup runs even if test fails or is interrupted
- Cleanup is idempotent (safe to run multiple times)
- No cleanup failures block test execution

### Test Independence

**Principles**:
1. **No shared state**: Each test creates its own temp directory
2. **No execution order dependency**: Tests can run in any order
3. **No external dependencies**: Tests don't rely on specific environment setup beyond standard Unix tools

**Verification**:
- Tests can be run individually: `bash tests/test-init-mode.sh`
- Tests can be run via runner: `make test`
- Order doesn't matter: Changing test order doesn't affect results

## Adding New Tests

### Step-by-Step Guide

1. **Create test file**: `tests/test-feature.sh`
2. **Add shebang and sources**:
   ```bash
   #!/bin/bash
   # test-feature.sh - Description of what this tests

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/assertions.sh"
   source "$SCRIPT_DIR/lib/test-utils.sh"
   ```

3. **Implement test functions**:
   ```bash
   test_feature_creates_files() {
       local test_dir
       test_dir=$(create_test_dir "feature")

       # Run installation
       run_agentize "$test_dir" "TestProject" "init"

       # Verify results
       assert_file_exists "$test_dir/.claude/CLAUDE.md"
       assert_dir_exists "$test_dir/.claude/agents"

       # Cleanup
       cleanup_test_dir "$test_dir"
   }
   ```

4. **Add test execution**:
   ```bash
   # At end of file
   test_feature_creates_files
   ```

5. **Make executable**: `chmod +x tests/test-feature.sh`

6. **Add to test runner**: Edit `tests/run-all.sh`, add to test list

7. **Verify**: Run `make test` to ensure new test executes

### Test Script Template

```bash
#!/bin/bash
# test-FEATURE.sh - Tests for FEATURE functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assertions.sh"
source "$SCRIPT_DIR/lib/test-utils.sh"

test_FEATURE_scenario_one() {
    local test_dir
    test_dir=$(create_test_dir "FEATURE-scenario1")

    # Setup
    run_agentize "$test_dir" "TestProject" "init"

    # Verify
    assert_file_exists "$test_dir/expected-file.txt"
    assert_dir_exists "$test_dir/expected-dir"

    # Cleanup
    cleanup_test_dir "$test_dir"
}

test_FEATURE_scenario_two() {
    local test_dir
    test_dir=$(create_test_dir "FEATURE-scenario2")

    # Setup, verify, cleanup...
}

# Execute all test functions
test_FEATURE_scenario_one
test_FEATURE_scenario_two
```

## CI Integration

### Exit Code Standards

**Standard**: Tests follow Unix conventions for exit codes
- **0**: All tests passed
- **Non-zero**: At least one test failed

**Implementation**:
- Each test script returns 0 on success, non-zero on any assertion failure
- Test runner accumulates failures and returns non-zero if any test failed
- CI systems (GitHub Actions, Jenkins, etc.) interpret non-zero as build failure

**Example CI usage**:
```yaml
# .github/workflows/test.yml
- name: Run tests
  run: make test  # Exits non-zero if tests fail, failing the CI job
```

### Output Format

**Current**: Simple human-readable output
```
[PASS] test-init-mode.sh
[FAIL] test-port-mode.sh: Expected .claude/ directory not found
```

**Future enhancements** (not implemented yet):
- **TAP (Test Anything Protocol)**: Structured output for test result parsers
  ```
  1..3
  ok 1 - test-init-mode.sh
  not ok 2 - test-port-mode.sh
  ok 3 - test-languages.sh
  ```
- **JUnit XML**: For integration with Jenkins and other CI tools
- **Verbose mode**: Detailed logging for debugging
- **Parallel execution**: Run tests concurrently for faster CI

These can be added later without breaking existing tests or CI integration.

## Troubleshooting

### Common Issues

#### Permission Errors in /tmp

**Symptom**: `mkdir: cannot create directory '/tmp/agentize-test-*': Permission denied`

**Cause**: Restrictive permissions on /tmp or disk full

**Solution**:
```bash
# Check /tmp permissions
ls -ld /tmp

# Check disk space
df -h /tmp

# If permissions issue, ensure /tmp is writable
sudo chmod 1777 /tmp  # Standard /tmp permissions
```

#### Cleanup Not Running

**Symptom**: Temp directories persist after test completion

**Cause**: `trap` not set up correctly or script exited before trap registration

**Solution**:
- Ensure `create_test_dir` is called before test logic
- Check that trap is registered: `trap -p` shows registered traps
- Manual cleanup: `make clean` removes all test artifacts

#### Test Isolation Failures

**Symptom**: Tests pass individually but fail when run together

**Cause**: Shared state or fixed temp directory names

**Solution**:
- Verify each test uses `create_test_dir` with unique suffix
- Check for hardcoded paths in test scripts
- Ensure tests don't modify source repository

### Debugging Techniques

#### Preserve Test Directory on Failure

**Temporary workaround** (until feature implemented):
```bash
# Comment out cleanup in test script
# cleanup_test_dir "$test_dir"

# Run test
bash tests/test-failing.sh

# Inspect temp directory
ls -la /tmp/agentize-test-*
```

#### Run Tests Individually

**Isolate failures**:
```bash
# Run only one test
bash tests/test-init-mode.sh

# Check exit code
echo $?  # 0 = pass, non-zero = fail
```

#### Verbose Bash Execution

**See all commands**:
```bash
# Run with xtrace
bash -x tests/test-init-mode.sh
```

#### Manual Test Execution

**Reproduce test scenario**:
```bash
# Create temp directory
TEST_DIR=$(mktemp -d "/tmp/agentize-test-manual-XXXXXX")

# Run installation
make agentize AGENTIZE_MASTER_PROJ="$TEST_DIR" AGENTIZE_PROJ_NAME="TestProject" AGENTIZE_MODE=init

# Inspect results
ls -la "$TEST_DIR"

# Cleanup
rm -rf "$TEST_DIR"
```

## Design Decisions

### Why Pure Bash?

**Decision**: Use pure bash scripts with custom assertions instead of external testing frameworks (BATS, ShellSpec, pytest).

**Rationale**:
1. **No external dependencies**: Matches project's minimalist philosophy
2. **Matches existing style**: install.sh is already bash
3. **Portable**: Works on any system with bash 3.2+ (macOS, Linux, etc.)
4. **Simple to understand**: No framework-specific syntax to learn
5. **Easy to debug**: Standard bash debugging techniques apply

**Tradeoffs**:
- Less sophisticated than BATS (no TAP output, parallel execution, advanced assertions)
- Requires custom implementation of common testing patterns
- More verbose for complex assertions

**Migration path**: If test suite grows complex, can migrate to BATS without changing test structure (BATS tests are also bash scripts).

### Why Not BATS?

**BATS (Bash Automated Testing System)** is the industry standard for bash testing.

**Why we didn't choose it**:
1. **External dependency**: Requires installation or vendoring
2. **Overkill for scope**: We have only 3-4 test scenarios currently
3. **Learning curve**: BATS-specific syntax (`@test`, `run`, `$status`) adds complexity
4. **Features we don't need**: TAP output, parallel execution not required yet

**When BATS makes sense**:
- Test suite grows beyond 10 test scripts
- CI/CD requires TAP output for result parsing
- Need advanced features like mocking, stubbing, test fixtures

**Current approach**: Start simple with pure bash, migrate to BATS if/when complexity justifies it.

### Why Not ShellSpec?

**ShellSpec** provides BDD-style testing with Given/When/Then syntax.

**Why we didn't choose it**:
1. **Audience mismatch**: BDD syntax targets non-technical stakeholders; all Agentize users are developers
2. **Complexity**: ShellSpec DSL adds learning curve without proportional benefit
3. **Scope mismatch**: BDD shines for behavior specification; we're testing file existence

**When ShellSpec makes sense**:
- Complex user workflows need specification
- Non-technical stakeholders need to understand tests
- Project adopts BDD methodology

### Why mktemp for Test Directories?

**Decision**: Use `mktemp -d` to create unique temporary directories instead of fixed paths or in-place testing.

**Rationale**:
1. **Security**: mktemp creates directories with restrictive permissions (700)
2. **Uniqueness**: Random suffixes prevent naming conflicts
3. **Parallel-safe**: Multiple test runs don't interfere
4. **Standard**: mktemp is POSIX and available everywhere

**Alternatives considered**:
- Fixed `/tmp/agentize-test`: Would conflict if multiple test runs
- In-place testing: Too dangerous, could corrupt source repository
- Per-test manual naming: Error-prone, hard to guarantee uniqueness

## References

### Testing Frameworks (Prior Art)

- [BATS Testing Framework](https://github.com/bats-core/bats-core) - Industry-standard bash testing framework with TAP output
- [ShellSpec](https://shellspec.info/) - BDD-style testing framework for POSIX shells
- [bash_unit](https://github.com/pgrange/bash_unit) - Minimal bash testing framework
- [test.sh](https://github.com/jtyers/test.sh) - Pure POSIX shell testing framework (similar approach to ours)

### Best Practices

- [mktemp Best Practices](https://www.putorius.net/mktemp-working-with-temporary-files.html) - Secure temporary file/directory creation
- [Test Isolation Strategies](https://habr.com/en/articles/655297/) - Shell script testing patterns
- [CI Exit Code Standards](https://dojofive.com/blog/how-ci-pipeline-scripts-and-exit-codes-interact/) - Exit code conventions for CI/CD

### Related Documentation

- [Testing Strategy (README.md)](../../README.md#testing-strategy) - Manual testing procedures
- [Test Directory README](../../tests/README.md) - Test execution guide
- [Test Library API](../../tests/lib/README.md) - Assertion and utility function reference
