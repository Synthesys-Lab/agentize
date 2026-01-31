#!/usr/bin/env bash
# Test: lol serve accepts no CLI flags (YAML-only configuration)

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

test_info "lol serve accepts no CLI flags (YAML-only configuration)"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Server starts without args (YAML-only for credentials and settings)
# (Server will fail later at bare repo check, which is expected)
output=$(lol serve 2>&1) || true
# Should NOT have TG-related or serve-flag CLI errors
if echo "$output" | grep -q "Error: --tg-token"; then
  test_fail "Should not mention --tg-token (removed from CLI)"
fi

# Test 2: --period is rejected (no longer accepted)
output=$(lol serve --period=5m 2>&1) || true
if ! echo "$output" | grep -q "Error:.*no longer accepts CLI flags\|configure.*\.agentize\.local\.yaml"; then
  test_fail "Should reject --period flag with YAML-only message"
fi

# Test 3: --num-workers is rejected (no longer accepted)
output=$(lol serve --num-workers=3 2>&1) || true
if ! echo "$output" | grep -q "Error:.*no longer accepts CLI flags\|configure.*\.agentize\.local\.yaml"; then
  test_fail "Should reject --num-workers flag with YAML-only message"
fi

# Test 4: Unknown option rejected
output=$(lol serve --unknown 2>&1) || true
if ! echo "$output" | grep -q "Error:"; then
  test_fail "Should reject unknown options"
fi

# Test 5: Completion outputs empty for serve-flags (no CLI flags)
output=$(lol --complete serve-flags 2>/dev/null)
# TG flags should NOT be in completion
if echo "$output" | grep -q "^--tg-token$"; then
  test_fail "Should NOT have --tg-token flag (moved to YAML-only)"
fi
if echo "$output" | grep -q "^--tg-chat-id$"; then
  test_fail "Should NOT have --tg-chat-id flag (moved to YAML-only)"
fi
# Server flags should NOT be in completion anymore
if echo "$output" | grep -q "^--period$"; then
  test_fail "Should NOT have --period flag (moved to YAML-only)"
fi
if echo "$output" | grep -q "^--num-workers$"; then
  test_fail "Should NOT have --num-workers flag (moved to YAML-only)"
fi

# Test 6: serve appears in command completion
output=$(lol --complete commands 2>/dev/null)
echo "$output" | grep -q "^serve$" || test_fail "Missing command: serve"

test_pass "lol serve accepts no CLI flags (YAML-only configuration)"
