#!/usr/bin/env bash
# Test: zsh completion for wt spawn and wt remove does not crash

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

test_info "zsh completion for wt spawn/remove does not crash"

# Skip if zsh is not available
if ! command -v zsh >/dev/null 2>&1; then
  echo "Skipping: zsh not available"
  exit 0
fi

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_wt"

if [ ! -f "$COMPLETION_FILE" ]; then
  test_fail "Completion file not found: $COMPLETION_FILE"
fi

# Test case 1: wt spawn with issue number
test_info "Test case 1: wt spawn 23<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/src/completion' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  # Mock wt command for completion helper
  wt() { true; }

  # Simulate tab completion for 'wt spawn 23'
  words=(wt spawn 23)
  CURRENT=3
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn completion crashes with 'doubled rest argument' error"
fi

# Test case 2: wt spawn with flag before issue number
test_info "Test case 2: wt spawn --yolo 23<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/src/completion' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt spawn --yolo 23)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn --yolo 23 completion crashes with 'doubled rest argument' error"
fi

# Test case 3: wt spawn with flag after issue number
test_info "Test case 3: wt spawn 23 --yolo<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/src/completion' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt spawn 23 --yolo)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn 23 --yolo completion crashes with 'doubled rest argument' error"
fi

# Test case 4: wt remove with flag
test_info "Test case 4: wt remove 23 --force<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/src/completion' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt remove 23 --force)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt remove 23 --force completion crashes with 'doubled rest argument' error"
fi

test_pass "zsh completion does not crash with doubled rest argument"
