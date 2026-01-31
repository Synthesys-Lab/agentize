#!/usr/bin/env bash
# Test: scripts/gh-graphql.sh review-threads and resolve-thread return fixture JSON in fixture mode

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

test_info "gh-graphql.sh review-threads returns expected fixture data"

# Run in fixture mode
export AGENTIZE_GH_API="fixture"

# Test 1: review-threads operation returns valid JSON
OUTPUT=$("$PROJECT_ROOT/scripts/gh-graphql.sh" review-threads TestOwner TestRepo 123)

if [ -z "$OUTPUT" ]; then
  test_fail "review-threads returned empty output"
fi

# Test 2: Verify JSON structure has required fields
if ! echo "$OUTPUT" | jq -e '.data.repository.pullRequest.reviewThreads.nodes' > /dev/null 2>&1; then
  test_fail "Missing reviewThreads.nodes structure in response"
fi

# Test 3: Verify unresolved threads are present with required fields
UNRESOLVED_COUNT=$(echo "$OUTPUT" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false)] | length')
if [ "$UNRESOLVED_COUNT" -lt 1 ]; then
  test_fail "Expected at least 1 unresolved non-outdated thread, got $UNRESOLVED_COUNT"
fi

# Test 4: Verify required fields exist on threads (path, line, isResolved)
FIRST_THREAD=$(echo "$OUTPUT" | jq '.data.repository.pullRequest.reviewThreads.nodes[0]')
if ! echo "$FIRST_THREAD" | jq -e '.path' > /dev/null 2>&1; then
  test_fail "Missing 'path' field on review thread"
fi
if ! echo "$FIRST_THREAD" | jq -e '.line' > /dev/null 2>&1; then
  test_fail "Missing 'line' field on review thread"
fi
if ! echo "$FIRST_THREAD" | jq -e 'has("isResolved")' > /dev/null 2>&1; then
  test_fail "Missing 'isResolved' field on review thread"
fi

# Test 5: Verify comments structure exists
if ! echo "$FIRST_THREAD" | jq -e '.comments.nodes' > /dev/null 2>&1; then
  test_fail "Missing 'comments.nodes' structure on review thread"
fi

test_pass "gh-graphql.sh review-threads returns expected fixture data"

# Test 6: resolve-thread operation returns valid JSON
test_info "gh-graphql.sh resolve-thread returns expected fixture data"

RESOLVE_OUTPUT=$("$PROJECT_ROOT/scripts/gh-graphql.sh" resolve-thread "PRRT_kwDOA1_test1")

if [ -z "$RESOLVE_OUTPUT" ]; then
  test_fail "resolve-thread returned empty output"
fi

# Test 7: Verify resolve-thread response has isResolved=true
IS_RESOLVED=$(echo "$RESOLVE_OUTPUT" | jq -r '.data.resolveReviewThread.thread.isResolved')
if [ "$IS_RESOLVED" != "true" ]; then
  test_fail "Expected isResolved=true, got $IS_RESOLVED"
fi

# Test 8: Verify resolve-thread response includes thread id
THREAD_ID=$(echo "$RESOLVE_OUTPUT" | jq -r '.data.resolveReviewThread.thread.id')
if [ -z "$THREAD_ID" ] || [ "$THREAD_ID" = "null" ]; then
  test_fail "Missing thread id in resolve-thread response"
fi

test_pass "gh-graphql.sh resolve-thread returns expected fixture data"
