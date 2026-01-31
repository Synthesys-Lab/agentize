#!/bin/bash
# Test strict shell enforcement when TEST_SHELLS is explicitly set

# Inlined shared test helpers (former tests/common.sh)
set -e

# ============================================================
# Test isolation: Clear Telegram environment variables
# ============================================================
# Prevents tests from accidentally sending Telegram API requests
# when developer environments have these variables set
unset AGENTIZE_USE_TG TG_API_TOKEN TG_CHAT_ID TG_ALLOWED_USER_IDS TG_APPROVAL_TIMEOUT_SEC TG_POLL_INTERVAL_SEC

# ============================================================
# Project root detection
# ============================================================

# Helper function to get the current project root (current worktree being tested)
# This is different from AGENTIZE_HOME which points to the agentize framework installation
get_project_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get project root using shell-neutral approach
# For test isolation, always use the current worktree (ignore parent AGENTIZE_HOME)
PROJECT_ROOT="$(get_project_root)"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Run from git repo."
  exit 1
fi

# Export AGENTIZE_HOME for tests - this is the framework installation path
# Tests use the current project root as the framework location
export AGENTIZE_HOME="$PROJECT_ROOT"

TESTS_DIR="$PROJECT_ROOT/tests"

# ============================================================
# Color constants for terminal output
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Test result helpers
# ============================================================

# Print test pass message and exit with success
# Usage: test_pass "message"
test_pass() {
  echo -e "${GREEN}✓ Test passed: $1${NC}"
  exit 0
}

# Print test fail message and exit with failure
# Usage: test_fail "message"
test_fail() {
  echo -e "${RED}✗ Test failed: $1${NC}"
  exit 1
}

# Print test info message
# Usage: test_info "message"
test_info() {
  echo -e "${BLUE}>>> $1${NC}"
}

# ============================================================
# Git environment cleanup
# ============================================================

# Clean all git environment variables to ensure isolated test environment
# Usage: clean_git_env
clean_git_env() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    unset GIT_INDEX_VERSION GIT_COMMON_DIR
}

# ============================================================
# Resource management
# ============================================================

# Create a temporary directory under .tmp and return its path
# Usage: TMP_DIR=$(make_temp_dir "test-name")
make_temp_dir() {
  local test_name="$1"
  local tmp_dir="$PROJECT_ROOT/.tmp/$test_name"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  echo "$tmp_dir"
}

# Clean up a directory
# Usage: cleanup_dir "$TMP_DIR"
cleanup_dir() {
  local dir="$1"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    rm -rf "$dir"
  fi
}

test_info "Testing strict shell enforcement for missing shells"

# Create a temporary directory for test output
TMP_DIR=$(make_temp_dir "test-strict-shells")

# Test 1: Explicitly set TEST_SHELLS with a non-existent shell
test_info "Running test-all.sh with TEST_SHELLS containing missing shell"

# Use a non-existent category to avoid recursively running other tests
# The strict shell check should fail before attempting to run tests
# Temporarily disable set -e to capture exit code
set +e
TEST_SHELLS="bash definitely_missing_shell_xyz" "$PROJECT_ROOT/tests/test-all.sh" nonexistent_category > "$TMP_DIR/output.txt" 2>&1
EXIT_CODE=$?
set -e

test_info "Exit code: $EXIT_CODE"
test_info "Output:"
cat "$TMP_DIR/output.txt"

# Verify that the script exited with error
if [ $EXIT_CODE -eq 0 ]; then
  cleanup_dir "$TMP_DIR"
  test_fail "test-all.sh should exit with non-zero when missing required shell"
fi

# Verify error message mentions the missing shell
if ! grep -q "definitely_missing_shell_xyz" "$TMP_DIR/output.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Error message should mention the missing shell"
fi

# Verify error message is clear about the requirement
if ! grep -qi "not found\|missing\|unavailable\|required" "$TMP_DIR/output.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Error message should clearly indicate the shell is missing/required"
fi

# Test 2: Verify bash-only (default) still works
test_info "Verifying default bash-only behavior still works"
unset TEST_SHELLS
set +e
"$PROJECT_ROOT/tests/test-all.sh" nonexistent_category > "$TMP_DIR/output2.txt" 2>&1
EXIT_CODE2=$?
set -e

# Should exit cleanly (no tests found is OK, but shell validation should pass)
# Exit code may be non-zero if no tests found, but should not be shell-related error
if grep -qi "shell.*not found\|shell.*missing" "$TMP_DIR/output2.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Default bash-only mode should not fail on shell availability"
fi

cleanup_dir "$TMP_DIR"
test_pass "Strict shell enforcement works correctly"
