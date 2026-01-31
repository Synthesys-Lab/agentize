#!/usr/bin/env bash
# Test: wt --complete commands outputs documented subcommands

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

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

test_info "wt --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Get output from wt --complete commands
output=$(wt --complete commands 2>/dev/null)

# Verify documented commands are present
# Check each command individually (shell-neutral approach)
echo "$output" | grep -q "^clone$" || test_fail "Missing command: clone"
echo "$output" | grep -q "^common$" || test_fail "Missing command: common"
echo "$output" | grep -q "^init$" || test_fail "Missing command: init"
echo "$output" | grep -q "^goto$" || test_fail "Missing command: goto"
echo "$output" | grep -q "^spawn$" || test_fail "Missing command: spawn"
echo "$output" | grep -q "^list$" || test_fail "Missing command: list"
echo "$output" | grep -q "^remove$" || test_fail "Missing command: remove"
echo "$output" | grep -q "^prune$" || test_fail "Missing command: prune"
echo "$output" | grep -q "^purge$" || test_fail "Missing command: purge"
echo "$output" | grep -q "^pathto$" || test_fail "Missing command: pathto"
echo "$output" | grep -q "^rebase$" || test_fail "Missing command: rebase"
echo "$output" | grep -q "^help$" || test_fail "Missing command: help"

# Verify legacy 'main' alias is NOT included (undocumented, compatibility only)
if echo "$output" | grep -q "^main$"; then
  test_fail "Should not include undocumented 'main' alias"
fi

# Verify legacy 'create' alias is NOT included (not documented)
if echo "$output" | grep -q "^create$"; then
  test_fail "Should not include undocumented 'create' alias"
fi

# Verify legacy 'resolve' is NOT included (replaced by pathto)
if echo "$output" | grep -q "^resolve$"; then
  test_fail "Should not include removed 'resolve' command (use pathto instead)"
fi

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "wt --complete commands outputs correct subcommands"
