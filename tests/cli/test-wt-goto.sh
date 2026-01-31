#!/usr/bin/env bash
# Test: wt goto changes directory to worktree targets

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

test_info "wt goto changes directory to worktree targets"

setup_test_repo
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Verify trees/main was created
if [ ! -d "trees/main" ]; then
  cleanup_test_repo
  test_fail "trees/main was not created by wt init"
fi

# Verify refspec and prune config after init (when origin exists)
# The test repo created by helpers-worktree.sh has an origin remote from clone
if git remote get-url origin >/dev/null 2>&1; then
  refspec=$(git config --get remote.origin.fetch 2>/dev/null)
  if [ "$refspec" != "+refs/heads/*:refs/remotes/origin/*" ]; then
    cleanup_test_repo
    test_fail "remote.origin.fetch not set correctly after init: got '$refspec'"
  fi

  prune_setting=$(git config --get fetch.prune 2>/dev/null)
  if [ "$prune_setting" != "true" ]; then
    cleanup_test_repo
    test_fail "fetch.prune not set to true after init: got '$prune_setting'"
  fi
fi

# Test: wt goto main
cd "$TEST_REPO_DIR"
wt goto main 2>/dev/null
current_dir=$(pwd)
expected_dir="$TEST_REPO_DIR/trees/main"

if [ "$current_dir" != "$expected_dir" ]; then
  cleanup_test_repo
  test_fail "wt goto main failed: expected $expected_dir, got $current_dir"
fi

# Create a worktree for issue-42
cd "$TEST_REPO_DIR"
wt spawn 42 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 42 failed"

# Test: wt goto 42
cd "$TEST_REPO_DIR"
wt goto 42 2>/dev/null
current_dir=$(pwd)

# Find the issue-42 directory (matches both "issue-42" and "issue-42-title")
issue_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "Could not find issue-42 worktree directory"
fi

if [ "$current_dir" != "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "wt goto 42 failed: expected $issue_dir, got $current_dir"
fi

# Test: wt goto with non-existent issue should fail gracefully
cd "$TEST_REPO_DIR"
if wt goto 999 2>/dev/null; then
  cleanup_test_repo
  test_fail "wt goto 999 should fail for non-existent worktree"
fi

cleanup_test_repo
test_pass "wt goto correctly changes directory to worktree targets"
