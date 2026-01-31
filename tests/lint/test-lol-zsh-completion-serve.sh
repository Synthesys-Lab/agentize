#!/usr/bin/env bash
# Test: lol serve subcommand has complete zsh completion support (no CLI flags)

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

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_lol"

test_info "lol serve has complete zsh completion support (no CLI flags)"

# Test 1: Verify 'serve' appears in static fallback command list
if ! grep -E "^\s+'serve:" "$COMPLETION_FILE" >/dev/null; then
  test_fail "'serve' not found in static fallback command list"
fi

# Test 2: Verify _lol_serve() helper function exists
if ! grep -q "^_lol_serve()" "$COMPLETION_FILE"; then
  test_fail "_lol_serve() helper function not found"
fi

# Test 3: Verify args case statement includes 'serve' handler
if ! grep -q "serve)" "$COMPLETION_FILE"; then
  test_fail "'serve' case handler not found in args switch"
fi

# Test 4: Verify dynamic description mapping includes 'serve'
if ! grep -q 'serve) commands_with_desc' "$COMPLETION_FILE"; then
  test_fail "'serve' not found in dynamic description mapping"
fi

# Test 5: Verify _lol_serve() does NOT have old TG flags (YAML-only now)
if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-token"; then
  test_fail "_lol_serve() should NOT have --tg-token flag (moved to YAML-only)"
fi

if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-chat-id"; then
  test_fail "_lol_serve() should NOT have --tg-chat-id flag (moved to YAML-only)"
fi

# Test 6: Verify _lol_serve() does NOT have --period or --num-workers (YAML-only now)
if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--period"; then
  test_fail "_lol_serve() should NOT have --period flag (moved to YAML-only)"
fi

if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--num-workers"; then
  test_fail "_lol_serve() should NOT have --num-workers flag (moved to YAML-only)"
fi

# Test 7: Verify _lol_serve() provides YAML-only documentation
if ! grep -A10 "^_lol_serve()" "$COMPLETION_FILE" | grep -q "\.agentize\.local\.yaml\|YAML"; then
  test_fail "_lol_serve() should mention YAML configuration"
fi

test_pass "lol serve has complete zsh completion support (no CLI flags)"
