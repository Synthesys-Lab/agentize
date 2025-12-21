#!/bin/bash
# assertions.sh - Assertion library for Agentize tests
#
# Provides assertion functions for test validation. All assertions print
# descriptive error messages and exit with code 1 on failure.
#
# Usage:
#   source "$(dirname "$0")/lib/assertions.sh"
#   assert_file_exists "/path/to/file"

set -euo pipefail

# ============================================================================
# Assertion Functions
# ============================================================================

# assert_file_exists - Verify file exists at path
#
# Usage: assert_file_exists <path>
# Example: assert_file_exists "$TEST_DIR/.claude/CLAUDE.md"
#
# Exits with code 1 if file does not exist
assert_file_exists() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "FAIL: File not found: $path" >&2
        exit 1
    fi
}

# assert_dir_exists - Verify directory exists at path
#
# Usage: assert_dir_exists <path>
# Example: assert_dir_exists "$TEST_DIR/.claude/agents"
#
# Exits with code 1 if directory does not exist
assert_dir_exists() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        echo "FAIL: Directory not found: $path" >&2
        exit 1
    fi
}

# assert_file_contains - Verify file contains pattern (grep regex)
#
# Usage: assert_file_contains <path> <pattern>
# Example: assert_file_contains "$TEST_DIR/Makefile" "build-python"
#
# Exits with code 1 if pattern not found in file
assert_file_contains() {
    local path="$1"
    local pattern="$2"

    if [[ ! -f "$path" ]]; then
        echo "FAIL: File not found: $path" >&2
        exit 1
    fi

    if ! grep -q "$pattern" "$path"; then
        echo "FAIL: Pattern '$pattern' not found in $path" >&2
        exit 1
    fi
}

# assert_command_succeeds - Run command and verify exit code 0
#
# Usage: assert_command_succeeds <command>
# Example: assert_command_succeeds "make -C $TEST_DIR build"
#
# Exits with code 1 if command exits with non-zero code
assert_command_succeeds() {
    local command="$1"
    local exit_code=0

    eval "$command" > /dev/null 2>&1 || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "FAIL: Command failed with exit code $exit_code: $command" >&2
        exit 1
    fi
}

# fail - Explicitly fail test with custom message
#
# Usage: fail <message>
# Example: fail "Expected 13 files in agents/ but found $count"
#
# Always exits with code 1
fail() {
    local message="$1"
    echo "FAIL: $message" >&2
    exit 1
}
