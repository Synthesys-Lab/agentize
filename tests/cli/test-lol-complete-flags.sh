#!/usr/bin/env bash
# Test: lol --complete flag topics output documented flags

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

test_info "lol --complete flag topics output documented flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test project-modes
project_modes_output=$(lol --complete project-modes 2>/dev/null)

echo "$project_modes_output" | grep -q "^--create$" || test_fail "project-modes missing: --create"
echo "$project_modes_output" | grep -q "^--associate$" || test_fail "project-modes missing: --associate"
echo "$project_modes_output" | grep -q "^--automation$" || test_fail "project-modes missing: --automation"

# Test project-create-flags
project_create_output=$(lol --complete project-create-flags 2>/dev/null)

echo "$project_create_output" | grep -q "^--org$" || test_fail "project-create-flags missing: --org"
echo "$project_create_output" | grep -q "^--title$" || test_fail "project-create-flags missing: --title"

# Test project-automation-flags
project_automation_output=$(lol --complete project-automation-flags 2>/dev/null)

echo "$project_automation_output" | grep -q "^--write$" || test_fail "project-automation-flags missing: --write"

# Test claude-clean-flags
claude_clean_output=$(lol --complete claude-clean-flags 2>/dev/null)

echo "$claude_clean_output" | grep -q "^--dry-run$" || test_fail "claude-clean-flags missing: --dry-run"

# Test usage-flags
usage_output=$(lol --complete usage-flags 2>/dev/null)

echo "$usage_output" | grep -q "^--today$" || test_fail "usage-flags missing: --today"
echo "$usage_output" | grep -q "^--week$" || test_fail "usage-flags missing: --week"
echo "$usage_output" | grep -q "^--cache$" || test_fail "usage-flags missing: --cache"
echo "$usage_output" | grep -q "^--cost$" || test_fail "usage-flags missing: --cost"

# Test plan-flags
plan_output=$(lol --complete plan-flags 2>/dev/null)

echo "$plan_output" | grep -q "^--dry-run$" || test_fail "plan-flags missing: --dry-run"
echo "$plan_output" | grep -q "^--verbose$" || test_fail "plan-flags missing: --verbose"
echo "$plan_output" | grep -q "^--refine$" || test_fail "plan-flags missing: --refine"
echo "$plan_output" | grep -q "^--editor$" || test_fail "plan-flags missing: --editor"

# Test impl-flags
impl_output=$(lol --complete impl-flags 2>/dev/null)

echo "$impl_output" | grep -q "^--backend$" || test_fail "impl-flags missing: --backend"
echo "$impl_output" | grep -q "^--max-iterations$" || test_fail "impl-flags missing: --max-iterations"
echo "$impl_output" | grep -q "^--yolo$" || test_fail "impl-flags missing: --yolo"

# Test unknown topic returns empty
unknown_output=$(lol --complete unknown-topic 2>/dev/null)
if [ -n "$unknown_output" ]; then
  test_fail "Unknown topic should return empty output"
fi

# Verify removed topics return empty (apply-flags, init-flags, update-flags, lang-values)
apply_output=$(lol --complete apply-flags 2>/dev/null)
if [ -n "$apply_output" ]; then
  test_fail "apply-flags topic should have been removed (should return empty)"
fi

init_output=$(lol --complete init-flags 2>/dev/null)
if [ -n "$init_output" ]; then
  test_fail "init-flags topic should have been removed (should return empty)"
fi

update_output=$(lol --complete update-flags 2>/dev/null)
if [ -n "$update_output" ]; then
  test_fail "update-flags topic should have been removed (should return empty)"
fi

lang_output=$(lol --complete lang-values 2>/dev/null)
if [ -n "$lang_output" ]; then
  test_fail "lang-values topic should have been removed (should return empty)"
fi

test_pass "lol --complete flag topics output correct flags"
