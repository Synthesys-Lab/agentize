#!/usr/bin/env bash
# Test: wt --complete flag topics output documented flags

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

test_info "wt --complete flag topics output documented flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Test spawn-flags
spawn_output=$(wt --complete spawn-flags 2>/dev/null)

if ! echo "$spawn_output" | grep -q "^--yolo$"; then
  test_fail "spawn-flags missing: --yolo"
fi

if ! echo "$spawn_output" | grep -q "^--no-agent$"; then
  test_fail "spawn-flags missing: --no-agent"
fi

if ! echo "$spawn_output" | grep -q "^--headless$"; then
  test_fail "spawn-flags missing: --headless"
fi

# Test remove-flags
remove_output=$(wt --complete remove-flags 2>/dev/null)

if ! echo "$remove_output" | grep -q "^--delete-branch$"; then
  test_fail "remove-flags missing: --delete-branch"
fi

if ! echo "$remove_output" | grep -q "^-D$"; then
  test_fail "remove-flags missing: -D (legacy alias)"
fi

if ! echo "$remove_output" | grep -q "^--force$"; then
  test_fail "remove-flags missing: --force (legacy alias)"
fi

# Verify output is newline-delimited
if echo "$spawn_output" | grep -q " "; then
  test_fail "spawn-flags output should be newline-delimited"
fi

if echo "$remove_output" | grep -q " "; then
  test_fail "remove-flags output should be newline-delimited"
fi

# Test rebase-flags
rebase_output=$(wt --complete rebase-flags 2>/dev/null)

if ! echo "$rebase_output" | grep -q "^--headless$"; then
  test_fail "rebase-flags missing: --headless"
fi

if ! echo "$rebase_output" | grep -q "^--yolo$"; then
  test_fail "rebase-flags missing: --yolo"
fi

# Verify rebase-flags output is newline-delimited
if echo "$rebase_output" | grep -q " "; then
  test_fail "rebase-flags output should be newline-delimited"
fi

# Test unknown topic returns empty
unknown_output=$(wt --complete unknown-topic 2>/dev/null)
if [ -n "$unknown_output" ]; then
  test_fail "Unknown topic should return empty output"
fi

test_pass "wt --complete flag topics output correct flags"
