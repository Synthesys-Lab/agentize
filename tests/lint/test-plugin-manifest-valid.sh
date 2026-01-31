#!/usr/bin/env bash
# Test: Plugin manifest validation

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

test_info "Plugin manifest validation"

PLUGIN_JSON="$PROJECT_ROOT/.claude-plugin/marketplace.json"

# Check plugin.json exists
if [ ! -f "$PLUGIN_JSON" ]; then
    test_fail "Plugin manifest not found at $PLUGIN_JSON"
fi

# Validate JSON syntax
if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
    test_fail "Plugin manifest has invalid JSON syntax"
fi

# Check required field: name
NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
if [ -z "$NAME" ]; then
    test_fail "Plugin manifest missing required field: name"
fi

# Validate referenced paths exist
COMMANDS_PATH=$(jq -r '.commands // empty' "$PLUGIN_JSON")
if [ -n "$COMMANDS_PATH" ]; then
    COMMANDS_DIR="$PROJECT_ROOT/${COMMANDS_PATH#./}"
    if [ ! -d "$COMMANDS_DIR" ]; then
        test_fail "Commands directory not found: $COMMANDS_DIR"
    fi
fi

SKILLS_PATH=$(jq -r '.skills // empty' "$PLUGIN_JSON")
if [ -n "$SKILLS_PATH" ]; then
    SKILLS_DIR="$PROJECT_ROOT/${SKILLS_PATH#./}"
    if [ ! -d "$SKILLS_DIR" ]; then
        test_fail "Skills directory not found: $SKILLS_DIR"
    fi
fi

AGENTS_PATH=$(jq -r '.agents // empty' "$PLUGIN_JSON")
if [ -n "$AGENTS_PATH" ]; then
    AGENTS_DIR="$PROJECT_ROOT/${AGENTS_PATH#./}"
    if [ ! -d "$AGENTS_DIR" ]; then
        test_fail "Agents directory not found: $AGENTS_DIR"
    fi
fi

HOOKS_PATH=$(jq -r '.hooks // empty' "$PLUGIN_JSON")
if [ -n "$HOOKS_PATH" ]; then
    HOOKS_FILE="$PROJECT_ROOT/${HOOKS_PATH#./}"
    if [ ! -f "$HOOKS_FILE" ]; then
        test_fail "Hooks file not found: $HOOKS_FILE"
    fi
fi

test_pass "Plugin manifest is valid with name='$NAME'"
