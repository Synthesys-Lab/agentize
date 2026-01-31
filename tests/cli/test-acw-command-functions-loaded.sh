#!/usr/bin/env bash
# Test: Only public acw_* functions are exposed after sourcing acw.sh
# Private helper functions should be prefixed with _acw_ and not appear in public API

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

test_info "Testing acw public API - only public functions should be exposed"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# List of expected PUBLIC functions (only acw is public)
EXPECTED_PUBLIC_FUNCTIONS=(
    "acw"
)

# List of PRIVATE functions that should exist but be prefixed with _acw_
EXPECTED_PRIVATE_FUNCTIONS=(
    "_acw_validate_args"
    "_acw_check_cli"
    "_acw_ensure_output_dir"
    "_acw_check_input_file"
    "_acw_invoke_claude"
    "_acw_invoke_codex"
    "_acw_invoke_opencode"
    "_acw_invoke_cursor"
    "_acw_complete"
)

# Check each public function is defined
test_info "Checking public functions exist"
for func in "${EXPECTED_PUBLIC_FUNCTIONS[@]}"; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Public function '$func' is not defined after sourcing acw.sh"
    fi
done

# Check each private function is defined (with underscore prefix)
test_info "Checking private functions exist with _acw_ prefix"
for func in "${EXPECTED_PRIVATE_FUNCTIONS[@]}"; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Private function '$func' is not defined after sourcing acw.sh"
    fi
done

# Verify old public helpers are NOT available (should be renamed to _acw_)
test_info "Checking old acw_* helper names are removed"
OLD_HELPER_NAMES=(
    "acw_validate_args"
    "acw_check_cli"
    "acw_ensure_output_dir"
    "acw_check_input_file"
    "acw_invoke_claude"
    "acw_invoke_codex"
    "acw_invoke_opencode"
    "acw_invoke_cursor"
    "acw_complete"
)

for func in "${OLD_HELPER_NAMES[@]}"; do
    if type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Old helper '$func' should be renamed to '_$func' but still exists"
    fi
done

test_pass "Public API has ${#EXPECTED_PUBLIC_FUNCTIONS[@]} functions, ${#EXPECTED_PRIVATE_FUNCTIONS[@]} private helpers correctly prefixed"
