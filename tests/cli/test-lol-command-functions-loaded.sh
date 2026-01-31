#!/usr/bin/env bash
# Test: Private _lol_* functions are available and public lol_cmd_* are absent

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

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "Private _lol_* helpers are available and lol_cmd_* helpers are absent"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# List of expected command functions
EXPECTED_FUNCTIONS=(
    "_lol_cmd_upgrade"
    "_lol_cmd_version"
    "_lol_cmd_project"
    "_lol_cmd_serve"
    "_lol_cmd_claude_clean"
    "_lol_cmd_usage"
    "_lol_cmd_plan"
    "_lol_cmd_impl"
    "_lol_complete"
    "_lol_detect_lang"
)

# Check each function is defined (shell-agnostic approach)
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    # Use 'type' output which works in both bash and zsh
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function '$func' is not defined after sourcing lol.sh"
    fi
done

DISALLOWED_FUNCTIONS=(
    "lol_cmd_upgrade"
    "lol_cmd_version"
    "lol_cmd_project"
    "lol_cmd_serve"
    "lol_cmd_claude_clean"
    "lol_cmd_usage"
    "lol_cmd_plan"
    "lol_cmd_impl"
    "lol_complete"
    "lol_detect_lang"
)

for func in "${DISALLOWED_FUNCTIONS[@]}"; do
    if type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function '$func' should not be public after sourcing lol.sh"
    fi
done

test_pass "All ${#EXPECTED_FUNCTIONS[@]} _lol_* functions are available and public lol_cmd_* helpers are absent"
