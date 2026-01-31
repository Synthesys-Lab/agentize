#!/usr/bin/env bash
# Test: wt rebase command basic functionality

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
source "$(dirname "$0")/../helpers-worktree.sh"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

test_info "wt rebase command basic functionality"

# Setup test repo
setup_test_repo

# Initialize worktree environment
source "$WT_CLI"
wt init >/dev/null 2>&1

# Test 1: Missing PR number returns error
output=$(wt rebase 2>&1) || true
if ! echo "$output" | grep -qi "missing\|usage\|error"; then
  test_fail "wt rebase without PR number should show error"
fi

# Test 2: Non-numeric PR number returns error
output=$(wt rebase abc 2>&1) || true
if ! echo "$output" | grep -qi "numeric\|error"; then
  test_fail "wt rebase with non-numeric PR should show error"
fi

# Test 3: Unknown flag returns error
output=$(wt rebase 123 --unknown-flag 2>&1) || true
if ! echo "$output" | grep -qi "unknown\|error"; then
  test_fail "wt rebase with unknown flag should show error"
fi

# Test 4: --headless flag is parsed (doesn't fail due to flag parsing)
# This tests that the flag parsing works; actual rebase requires gh CLI mocking
output=$(wt rebase --headless 123 2>&1) || true
# Should fail for PR not found, not for flag parsing
if echo "$output" | grep -qi "unknown flag"; then
  test_fail "wt rebase --headless should be a valid flag"
fi

# Test 5: --yolo flag is parsed (doesn't fail due to flag parsing)
output=$(wt rebase --yolo 123 2>&1) || true
# Should fail for PR not found, not for flag parsing
if echo "$output" | grep -qi "unknown flag"; then
  test_fail "wt rebase --yolo should be a valid flag"
fi

# Test 6: rebase command exists in completion
output=$(wt --complete commands 2>/dev/null)
if ! echo "$output" | grep -q "^rebase$"; then
  test_fail "rebase should be in wt --complete commands"
fi

# Test 7: rebase-flags topic exists in completion
output=$(wt --complete rebase-flags 2>/dev/null)
if ! echo "$output" | grep -q "^--headless$"; then
  test_fail "--headless should be in wt --complete rebase-flags"
fi

if ! echo "$output" | grep -q "^--yolo$"; then
  test_fail "--yolo should be in wt --complete rebase-flags"
fi

if ! echo "$output" | grep -q "^--model$"; then
  test_fail "--model should be in wt --complete rebase-flags"
fi

# Test 8: --model flag is parsed (doesn't fail due to flag parsing)
output=$(wt rebase --model opus 123 2>&1) || true
# Should fail for PR not found, not for flag parsing
if echo "$output" | grep -qi "unknown flag"; then
  test_fail "wt rebase --model should be a valid flag"
fi

# Cleanup
cleanup_test_repo

test_pass "wt rebase command basic functionality"
