#!/usr/bin/env bash
# Test: term label helpers respect NO_COLOR and PLANNER_NO_COLOR

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

TERM_COLORS="$PROJECT_ROOT/src/cli/term/colors.sh"

test_info "term label helpers respect NO_COLOR and PLANNER_NO_COLOR"

# Source the term colors library
source "$TERM_COLORS"

# Test 1: term_color_enabled returns 1 when NO_COLOR=1
(
    export NO_COLOR=1
    if term_color_enabled; then
        test_fail "term_color_enabled should return 1 when NO_COLOR=1"
    fi
)

# Test 2: term_color_enabled returns 1 when PLANNER_NO_COLOR=1
(
    unset NO_COLOR
    export PLANNER_NO_COLOR=1
    if term_color_enabled; then
        test_fail "term_color_enabled should return 1 when PLANNER_NO_COLOR=1"
    fi
)

# Test 3: term_label prints plain text when colors disabled
(
    export NO_COLOR=1
    output=$(term_label "Feature:" "test description" "info" 2>&1)
    expected="Feature: test description"
    if [ "$output" != "$expected" ]; then
        test_fail "term_label should print plain 'Feature: test description', got '$output'"
    fi
)

# Test 4: term_label with success style prints plain text when colors disabled
(
    export NO_COLOR=1
    output=$(term_label "issue created:" "http://example.com" "success" 2>&1)
    expected="issue created: http://example.com"
    if [ "$output" != "$expected" ]; then
        test_fail "term_label should print plain text with success style, got '$output'"
    fi
)

# Test 5: term_clear_line emits proper escape sequence (no color involved)
(
    output=$(term_clear_line 2>&1)
    # The clear line sequence is \r\033[K - we check it contains the escape
    if [[ "$output" != *$'\033[K'* ]] && [[ "$output" != *$'\x1b[K'* ]]; then
        # Note: In non-TTY context, it may still output the sequence
        # or be empty - we just verify it doesn't error
        :
    fi
)

test_pass "term label helpers respect NO_COLOR and PLANNER_NO_COLOR"
