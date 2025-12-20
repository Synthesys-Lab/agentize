# Test Utilities Library

## Purpose

This directory contains shared utilities for Agentize tests. It provides assertion functions and setup/teardown helpers to simplify test writing and ensure consistent test patterns.

## Files

### assertions.sh

Assertion library providing test validation functions.

**Location**: `tests/lib/assertions.sh`

**Usage**: Source this file to access assertion helpers in your test scripts.

```bash
source "$(dirname "$0")/lib/assertions.sh"
```

### test-utils.sh

Test setup/teardown utilities for managing test environments.

**Location**: `tests/lib/test-utils.sh`

**Usage**: Source this file to access test infrastructure functions.

```bash
source "$(dirname "$0")/lib/test-utils.sh"
```

## Assertions API

All assertion functions print descriptive error messages and exit with non-zero code on failure, immediately failing the test.

### assert_file_exists

**Signature**: `assert_file_exists <path>`

**Purpose**: Verify that a file exists at the specified path.

**Parameters**:
- `path`: Absolute or relative path to file

**Behavior**:
- **Success**: File exists, continues execution
- **Failure**: Prints error message, exits with code 1

**Example**:
```bash
assert_file_exists "$TEST_DIR/.claude/CLAUDE.md"
assert_file_exists "$TEST_DIR/Makefile"
```

**Error output**:
```
FAIL: File not found: /tmp/agentize-test-init-abc123/.claude/CLAUDE.md
```

---

### assert_dir_exists

**Signature**: `assert_dir_exists <path>`

**Purpose**: Verify that a directory exists at the specified path.

**Parameters**:
- `path`: Absolute or relative path to directory

**Behavior**:
- **Success**: Directory exists, continues execution
- **Failure**: Prints error message, exits with code 1

**Example**:
```bash
assert_dir_exists "$TEST_DIR/.claude/agents"
assert_dir_exists "$TEST_DIR/docs"
```

**Error output**:
```
FAIL: Directory not found: /tmp/agentize-test-init-abc123/.claude/agents
```

---

### assert_file_contains

**Signature**: `assert_file_contains <path> <pattern>`

**Purpose**: Verify that a file contains a specific pattern (grep regex).

**Parameters**:
- `path`: Path to file to search
- `pattern`: Regular expression pattern to find (grep syntax)

**Behavior**:
- **Success**: Pattern found in file, continues execution
- **Failure**: Pattern not found, prints error message, exits with code 1

**Example**:
```bash
assert_file_contains "$TEST_DIR/Makefile" "build-python"
assert_file_contains "$TEST_DIR/pyproject.toml" "name = \"my_project\""
```

**Error output**:
```
FAIL: Pattern 'build-python' not found in /tmp/agentize-test-init-abc123/Makefile
```

**Notes**:
- Uses `grep -q` internally
- Pattern is a grep regular expression (not glob)
- Case-sensitive by default

---

### assert_command_succeeds

**Signature**: `assert_command_succeeds <command>`

**Purpose**: Run a command and verify it exits with code 0.

**Parameters**:
- `command`: Shell command to execute

**Behavior**:
- **Success**: Command exits 0, continues execution
- **Failure**: Command exits non-zero, prints error and exit code, exits test with code 1

**Example**:
```bash
assert_command_succeeds "make -C $TEST_DIR build"
assert_command_succeeds "python -m py_compile $TEST_DIR/lib/my_project/main.py"
```

**Error output**:
```
FAIL: Command failed with exit code 2: make -C /tmp/agentize-test-init-abc123 build
```

**Notes**:
- Command is executed in a subshell
- Standard output and standard error are displayed if command fails
- Use quotes around command if it contains spaces or special characters

---

### fail

**Signature**: `fail <message>`

**Purpose**: Explicitly fail the test with a custom error message.

**Parameters**:
- `message`: Error message to display

**Behavior**:
- Prints error message
- Exits test with code 1

**Example**:
```bash
file_count=$(find "$TEST_DIR/.claude/agents" -type f | wc -l)
if [ "$file_count" -ne 13 ]; then
    fail "Expected 13 files in agents/ but found $file_count"
fi
```

**Error output**:
```
FAIL: Expected 13 files in agents/ but found 10
```

**Use cases**:
- Complex conditions that don't fit existing assertions
- Custom validation logic
- Explicit test failures for edge cases

## Test Utilities API

### create_test_dir

**Signature**: `create_test_dir <name_suffix>`

**Purpose**: Create a unique temporary directory for test isolation.

**Parameters**:
- `name_suffix`: Short descriptor for the test scenario (e.g., "init", "port", "python")

**Returns**: Absolute path to created temporary directory (via stdout)

**Behavior**:
- Creates directory with pattern: `/tmp/agentize-test-<name_suffix>-XXXXXX`
- Sets up automatic cleanup on exit using `trap`
- Ensures directory has restrictive permissions (700)

**Example**:
```bash
test_dir=$(create_test_dir "init")
echo "Test directory: $test_dir"
# Output: Test directory: /tmp/agentize-test-init-a1b2c3

# Use the directory
run_agentize "$test_dir" "TestProject" "init"

# Automatic cleanup on exit (via trap)
```

**Notes**:
- Uses `mktemp -d` for secure unique directory creation
- Random suffix (`XXXXXX`) ensures uniqueness even if tests run in parallel
- Automatic cleanup via `trap` ensures resources are freed even on test failure
- Directory persists only for the duration of the test script

---

### cleanup_test_dir

**Signature**: `cleanup_test_dir <path>`

**Purpose**: Remove a temporary directory created by `create_test_dir`.

**Parameters**:
- `path`: Path to directory to remove (usually returned by `create_test_dir`)

**Behavior**:
- Removes directory and all contents
- Safe to call multiple times (idempotent)
- Silently succeeds if directory doesn't exist

**Example**:
```bash
test_dir=$(create_test_dir "port")

# Run test operations...

# Explicit cleanup (in addition to automatic trap cleanup)
cleanup_test_dir "$test_dir"
```

**Notes**:
- Usually not needed due to automatic `trap` cleanup
- Useful for explicit cleanup mid-test (e.g., testing multiple scenarios in one script)
- Safe to call even if directory was already cleaned up
- Uses `rm -rf` internally - be careful with the path!

---

### run_agentize

**Signature**: `run_agentize <target_dir> <project_name> <mode> [lang] [impl_dir]`

**Purpose**: Execute `make agentize` with given parameters in a consistent way.

**Parameters**:
- `target_dir`: Target directory for installation (AGENTIZE_MASTER_PROJ)
- `project_name`: Project name (AGENTIZE_PROJ_NAME)
- `mode`: Installation mode: `init` or `port` (AGENTIZE_MODE)
- `lang` (optional): Comma-separated language list (AGENTIZE_LANG)
- `impl_dir` (optional): Implementation directory name (AGENTIZE_IMPL_DIR)

**Behavior**:
- Constructs and executes `make agentize` command with proper variables
- Returns exit code from make command (0 = success, non-zero = failure)
- Displays make output to stdout/stderr

**Example**:
```bash
# Init mode, default C++ language
run_agentize "$test_dir" "TestProject" "init"

# Port mode (language doesn't matter, only .claude/ created)
run_agentize "$test_dir" "ExistingProject" "port"

# Python project with custom implementation directory
run_agentize "$test_dir" "MyPythonLib" "init" "python" "lib"

# Multi-language project
run_agentize "$test_dir" "HybridProject" "init" "python,cpp"
```

**Equivalent commands**:
```bash
# Example 1
make agentize AGENTIZE_MASTER_PROJ="$test_dir" \
              AGENTIZE_PROJ_NAME="TestProject" \
              AGENTIZE_MODE="init"

# Example 3
make agentize AGENTIZE_MASTER_PROJ="$test_dir" \
              AGENTIZE_PROJ_NAME="MyPythonLib" \
              AGENTIZE_MODE="init" \
              AGENTIZE_LANG="python" \
              AGENTIZE_IMPL_DIR="lib"
```

**Notes**:
- Wrapper around `make agentize` for consistency
- Automatically handles parameter formatting
- Can be used with `assert_command_succeeds` for explicit success verification
- Returns same exit code as make command

## Usage Patterns

### Basic Test Structure

```bash
#!/bin/bash
# test-example.sh - Example test demonstrating library usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assertions.sh"
source "$SCRIPT_DIR/lib/test-utils.sh"

test_example_scenario() {
    # 1. Create isolated test environment
    local test_dir
    test_dir=$(create_test_dir "example")

    # 2. Run installation
    run_agentize "$test_dir" "TestProject" "init"

    # 3. Verify results using assertions
    assert_dir_exists "$test_dir/.claude"
    assert_file_exists "$test_dir/.claude/CLAUDE.md"
    assert_file_contains "$test_dir/Makefile" "build"

    # 4. Explicit cleanup (in addition to automatic cleanup)
    cleanup_test_dir "$test_dir"
}

# Execute test
test_example_scenario
```

### Multiple Scenarios in One Test File

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assertions.sh"
source "$SCRIPT_DIR/lib/test-utils.sh"

test_scenario_one() {
    local test_dir
    test_dir=$(create_test_dir "scenario1")
    # ... test logic ...
    cleanup_test_dir "$test_dir"
}

test_scenario_two() {
    local test_dir
    test_dir=$(create_test_dir "scenario2")
    # ... test logic ...
    cleanup_test_dir "$test_dir"
}

# Execute all scenarios
test_scenario_one
test_scenario_two
```

### Custom Validation with Fail

```bash
test_file_count() {
    local test_dir
    test_dir=$(create_test_dir "count-check")

    run_agentize "$test_dir" "TestProject" "init"

    # Custom validation: count agents
    local agent_count
    agent_count=$(find "$test_dir/.claude/agents" -type f -name "*.md" | wc -l)

    if [ "$agent_count" -ne 13 ]; then
        fail "Expected 13 agent files but found $agent_count"
    fi

    cleanup_test_dir "$test_dir"
}
```

## Design Notes

### POSIX Compatibility

All functions use POSIX-compatible shell constructs to ensure portability:
- Works on Bash 3.2+ (macOS default)
- Works on modern Bash (5.x on Linux)
- Avoids bashisms where possible

### Trap-Based Cleanup

Automatic cleanup uses bash `trap` to ensure resources are freed even if:
- Test fails (assertion failure exits script)
- Script is interrupted (Ctrl+C)
- Test encounters error and exits early

**Implementation**:
```bash
create_test_dir() {
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/agentize-test-${1}-XXXXXX")
    trap "rm -rf '$temp_dir'" EXIT INT TERM
    echo "$temp_dir"
}
```

### No External Dependencies

All utilities use only standard Unix tools:
- `mktemp`: Temporary directory creation
- `grep`: Pattern matching for assertions
- `test` (`[`): File/directory existence checks
- `rm`, `find`, `wc`: Cleanup and counting

No installation or vendoring required.

### Error Messages

All assertions provide descriptive error messages:
- Include the failed condition
- Show relevant paths or values
- Prefix with `FAIL:` for easy grep filtering

**Example**:
```
FAIL: File not found: /tmp/agentize-test-init-abc123/.claude/CLAUDE.md
FAIL: Pattern 'build-python' not found in /tmp/agentize-test-init-abc123/Makefile
FAIL: Expected 13 files in agents/ but found 10
```

## Subdirectories

None. The `lib/` directory is flat - all utility files are at the top level.

## Related Documentation

- [Test Directory README](../README.md) - Test execution guide
- [Testing Infrastructure Architecture](../../docs/architecture/testing-infrastructure.md) - Design decisions and best practices
