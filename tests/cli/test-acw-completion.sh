#!/usr/bin/env bash
# Test: acw completion functionality
# Verifies acw --complete returns expected values for each topic

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

test_info "Testing acw completion functionality"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Test 1: acw --complete providers returns all providers
test_info "Checking --complete providers"
providers_output=$(acw --complete providers)

for provider in claude codex opencode cursor; do
    if ! echo "$providers_output" | grep -q "^${provider}$"; then
        test_fail "Provider '$provider' not found in --complete providers output"
    fi
done

# Test 2: acw --complete cli-options returns common flags
test_info "Checking --complete cli-options"
options_output=$(acw --complete cli-options)

for option in "--help" "--model" "--yolo" "--silent"; do
    if ! echo "$options_output" | grep -q "^${option}$"; then
        test_fail "Option '$option' not found in --complete cli-options output"
    fi
done

# Test 3: acw --complete with unknown topic returns empty (graceful degradation)
test_info "Checking --complete with unknown topic"
unknown_output=$(acw --complete unknown-topic 2>/dev/null)

if [ -n "$unknown_output" ]; then
    test_fail "Expected empty output for unknown completion topic, got: $unknown_output"
fi

# Test 4: _acw_complete function is available (private)
test_info "Checking _acw_complete function exists"
if ! type _acw_complete 2>/dev/null | grep -q "function"; then
    test_fail "_acw_complete function is not defined"
fi

# Test 5: old acw_complete function is NOT available
test_info "Checking old acw_complete function is removed"
if type acw_complete 2>/dev/null | grep -q "function"; then
    test_fail "Old acw_complete function should be renamed to _acw_complete"
fi

test_pass "All completion tests passed"
