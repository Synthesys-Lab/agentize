#!/usr/bin/env bash
# Test: acw validates missing required arguments

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

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw validates missing required arguments"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Test with no arguments - should fail with exit code 1
output=$(acw 2>&1 || true)
echo "$output" | grep -qi "usage\|error" || test_fail "No arguments should show usage or error"

# Test with only cli-name - should fail
output=$(acw claude 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing model should show error"

# Test with cli-name and model - should fail (missing input/output)
output=$(acw claude claude-sonnet-4-20250514 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing files should show error"

# Test with cli-name, model, and input - should fail (missing output)
output=$(acw claude claude-sonnet-4-20250514 /tmp/nonexistent.txt 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing output should show error"

# Test with unknown provider - should fail with exit code 2
exit_code=0
output=$(acw unknown-provider model input.txt output.txt 2>&1) || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Unknown provider should return exit code 2, got $exit_code"
echo "$output" | grep -qi "unknown\|unsupported\|provider" || test_fail "Unknown provider should show error"

test_pass "acw validates missing required arguments"
