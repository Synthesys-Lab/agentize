#!/bin/bash
# test-utils.sh - Test utilities for Agentize tests
#
# Provides setup/teardown utilities and helper functions for test infrastructure.
#
# Usage:
#   source "$(dirname "$0")/lib/test-utils.sh"
#   test_dir=$(create_test_dir "example")
#   cleanup_test_dir "$test_dir"

set -euo pipefail

# ============================================================================
# Color Codes (with TTY detection)
# ============================================================================

if [[ -t 1 ]]; then
    # TTY detected - use colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    # No TTY - plain text
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# ============================================================================
# Test Directory Management
# ============================================================================

# create_test_dir - Create unique temporary directory for test isolation
#
# Usage: test_dir=$(create_test_dir "name_suffix")
# Example: test_dir=$(create_test_dir "init")
#          # Returns: /tmp/agentize-test-init-a1b2c3
#
# Returns: Absolute path to created temporary directory
#
# Note: Caller is responsible for cleanup via cleanup_test_dir()
#       or temp dirs are auto-cleaned by make clean
create_test_dir() {
    local name_suffix="$1"
    local temp_dir

    # Create unique temporary directory
    temp_dir=$(mktemp -d "/tmp/agentize-test-${name_suffix}-XXXXXX")

    echo "$temp_dir"
}

# cleanup_test_dir - Remove temporary directory
#
# Usage: cleanup_test_dir <path>
# Example: cleanup_test_dir "$test_dir"
#
# Safe to call multiple times (idempotent)
# Silently succeeds if directory doesn't exist
cleanup_test_dir() {
    local path="$1"

    if [[ -d "$path" ]]; then
        rm -rf "$path"
    fi
}

# ============================================================================
# Agentize Execution Wrapper
# ============================================================================

# run_agentize - Execute make agentize with given parameters
#
# Usage: run_agentize <target_dir> <project_name> <mode> [lang] [impl_dir]
# Example: run_agentize "$test_dir" "TestProject" "init"
#          run_agentize "$test_dir" "MyPyLib" "init" "python" "lib"
#
# Parameters:
#   target_dir   - Target directory for installation (AGENTIZE_MASTER_PROJ)
#   project_name - Project name (AGENTIZE_PROJ_NAME)
#   mode         - Installation mode: 'init' or 'port' (AGENTIZE_MODE)
#   lang         - (optional) Comma-separated language list (AGENTIZE_LANG)
#   impl_dir     - (optional) Implementation directory name (AGENTIZE_IMPL_DIR)
#
# Returns: Exit code from make command (0 = success, non-zero = failure)
run_agentize() {
    local target_dir="$1"
    local project_name="$2"
    local mode="$3"
    local lang="${4:-}"
    local impl_dir="${5:-}"

    local cmd="make agentize"
    cmd+=" AGENTIZE_MASTER_PROJ='$target_dir'"
    cmd+=" AGENTIZE_PROJ_NAME='$project_name'"
    cmd+=" AGENTIZE_MODE='$mode'"

    if [[ -n "$lang" ]]; then
        cmd+=" AGENTIZE_LANG='$lang'"
    fi

    if [[ -n "$impl_dir" ]]; then
        cmd+=" AGENTIZE_IMPL_DIR='$impl_dir'"
    fi

    eval "$cmd"
}

# ============================================================================
# Output Formatting Helpers
# ============================================================================

# log_pass - Print PASS message with green color
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

# log_fail - Print FAIL message with red color
log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# log_info - Print INFO message with blue color
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# log_warning - Print WARNING message with yellow color
log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================================
# Test Result Tracking
# ============================================================================

# Global counters for test results
TESTS_PASSED=0
TESTS_FAILED=0

# increment_pass - Increment passed test counter
increment_pass() {
    ((TESTS_PASSED++)) || true
}

# increment_fail - Increment failed test counter
increment_fail() {
    ((TESTS_FAILED++)) || true
}

# print_test_summary - Print summary of test results
#
# Usage: print_test_summary
#
# Prints total passed and failed tests, returns exit code based on failures
print_test_summary() {
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    log_pass "$TESTS_PASSED tests passed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_fail "$TESTS_FAILED tests failed"
        return 1
    else
        log_info "All tests passed!"
        return 0
    fi
}
