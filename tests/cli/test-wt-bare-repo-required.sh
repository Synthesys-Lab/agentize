#!/usr/bin/env bash
# Test: wt init fails in non-bare repositories with clear error

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

test_info "wt init fails in non-bare repositories with clear error"

# Create a NON-bare test repo
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo "test" > README.md
git add README.md
git commit -m "Initial commit"

# Copy src/cli/wt.sh as wt-cli.sh for test sourcing
cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh

# Copy wt/ module directory for modular loading
cp -r "$PROJECT_ROOT/src/cli/wt" ./wt

source ./wt-cli.sh

# Try to run wt init - should fail
if wt init 2>/dev/null; then
  cd /
  rm -rf "$TEST_DIR"
  test_fail "wt init should fail in non-bare repository"
fi

# Verify error message mentions bare repository requirement
error_output=$(wt init 2>&1 || true)
if ! echo "$error_output" | grep -qi "bare"; then
  cd /
  rm -rf "$TEST_DIR"
  test_fail "Error message should mention 'bare' repository requirement"
fi

# Clean up
cd /
rm -rf "$TEST_DIR"

test_pass "wt init correctly rejects non-bare repositories"
