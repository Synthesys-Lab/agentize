#!/usr/bin/env bash
# Test: lol claude-clean removes stale project entries from ~/.claude.json

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

test_info "lol claude-clean removes stale project entries"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create temp directory for test
TMP_DIR=$(make_temp_dir "test-lol-claude-clean")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a valid directory and a path that doesn't exist
VALID_DIR="$TMP_DIR/valid-project"
STALE_PATH="$TMP_DIR/stale-project"
mkdir -p "$VALID_DIR"
# Note: STALE_PATH intentionally not created

# Create mock ~/.claude.json in temp location
MOCK_CLAUDE_JSON="$TMP_DIR/claude.json"
cat > "$MOCK_CLAUDE_JSON" << EOF
{
  "projects": {
    "$VALID_DIR": { "name": "valid" },
    "$STALE_PATH": { "name": "stale" }
  },
  "githubRepoPaths": {
    "owner/valid-repo": ["$VALID_DIR"],
    "owner/stale-repo": ["$STALE_PATH"],
    "owner/mixed-repo": ["$VALID_DIR", "$STALE_PATH"]
  }
}
EOF

# Override HOME for test
export HOME="$TMP_DIR"
mv "$MOCK_CLAUDE_JSON" "$TMP_DIR/.claude.json"

# Test 1: dry-run shows what would be removed
test_info "Test 1: dry-run shows stale entries"
dry_run_output=$(lol claude-clean --dry-run 2>&1)

echo "$dry_run_output" | grep -q "projects.*1" || test_fail "dry-run should report 1 stale project"
echo "$dry_run_output" | grep -q "$STALE_PATH" || test_fail "dry-run should list stale path"

# Verify file was NOT modified
after_dry_run=$(cat "$TMP_DIR/.claude.json")
echo "$after_dry_run" | jq -e ".projects[\"$STALE_PATH\"]" > /dev/null || test_fail "dry-run should not remove stale project"

# Test 2: apply removes stale entries
test_info "Test 2: apply removes stale entries"
apply_output=$(lol claude-clean 2>&1)

# Verify stale .projects key is removed
after_apply=$(cat "$TMP_DIR/.claude.json")
if echo "$after_apply" | jq -e ".projects[\"$STALE_PATH\"]" > /dev/null 2>&1; then
  test_fail "apply should remove stale project key"
fi

# Verify valid .projects key is preserved
echo "$after_apply" | jq -e ".projects[\"$VALID_DIR\"]" > /dev/null || test_fail "apply should preserve valid project key"

# Verify stale repo in .githubRepoPaths is removed (empty array case)
if echo "$after_apply" | jq -e ".githubRepoPaths[\"owner/stale-repo\"]" > /dev/null 2>&1; then
  test_fail "apply should remove repo key with all stale paths"
fi

# Verify valid repo is preserved
echo "$after_apply" | jq -e ".githubRepoPaths[\"owner/valid-repo\"]" > /dev/null || test_fail "apply should preserve repo with valid paths"

# Verify mixed repo has stale path removed but valid preserved
mixed_paths=$(echo "$after_apply" | jq -r '.githubRepoPaths["owner/mixed-repo"][]' 2>/dev/null)
echo "$mixed_paths" | grep -q "$VALID_DIR" || test_fail "mixed repo should preserve valid path"
if echo "$mixed_paths" | grep -q "$STALE_PATH"; then
  test_fail "mixed repo should remove stale path"
fi

# Test 3: no stale entries case
test_info "Test 3: no stale entries reports nothing to clean"
# Run again - should report no stale entries
no_stale_output=$(lol claude-clean --dry-run 2>&1)
echo "$no_stale_output" | grep -qi "no stale" || test_fail "should report no stale entries"

test_pass "lol claude-clean correctly handles stale project entries"
