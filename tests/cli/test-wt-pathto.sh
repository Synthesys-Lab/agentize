#!/usr/bin/env bash
# Test: wt pathto prints worktree paths

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

test_info "wt pathto prints worktree paths"

setup_test_repo
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Test: wt pathto main returns trees/main path
output=$(wt pathto main 2>/dev/null)
expected_path="$TEST_REPO_DIR/trees/main"

if [ "$output" != "$expected_path" ]; then
  cleanup_test_repo
  test_fail "wt pathto main failed: expected $expected_path, got $output"
fi

# Verify exit code is 0
if ! wt pathto main >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto main should exit 0"
fi

# Create a worktree for issue-42
wt spawn 42 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 42 failed"

# Test: wt pathto 42 returns issue-42 path
output=$(wt pathto 42 2>/dev/null)

# Find the actual issue-42 directory
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "Could not find issue-42 worktree directory"
fi

if [ "$output" != "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "wt pathto 42 failed: expected $issue_dir, got $output"
fi

# Verify exit code is 0 for existing worktree
if ! wt pathto 42 >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto 42 should exit 0 for existing worktree"
fi

# Test: wt pathto with non-existent issue should fail (exit 1)
if wt pathto 999 >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto 999 should exit non-zero for non-existent worktree"
fi

# Test: wt pathto without argument should fail
if wt pathto >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto without argument should exit non-zero"
fi

cleanup_test_repo
test_pass "wt pathto correctly prints worktree paths"
