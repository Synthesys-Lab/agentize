#!/usr/bin/env bash
# Test: lol project --automation outputs workflow template

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

test_info "lol project --automation outputs workflow template"

TMP_DIR=$(make_temp_dir "lol-project-automation")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Add org and id to metadata for automation test
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 42
git:
  default_branch: main
EOF

    # Test automation template generation
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="automation"
    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Check output contains workflow YAML
    if ! echo "$output" | grep -q "name: Add issues and PRs to project"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing workflow name"
    fi

    # Check that org and id are substituted
    if ! echo "$output" | grep -q "PROJECT_ORG: test-org"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing org substitution"
    fi

    if ! echo "$output" | grep -q "PROJECT_ID: 42"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing id substitution"
    fi

    # Verify STAGE_FIELD_ID is NOT present (uses Status field by name, no ID needed)
    if echo "$output" | grep -q "STAGE_FIELD_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should not have STAGE_FIELD_ID (uses Status field by name)"
    fi

    # Check for status-field/status-value in issue add step
    if ! echo "$output" | grep -q "status-field:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing status-field for issues"
    fi

    if ! echo "$output" | grep -q "status-value:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing status-value for issues"
    fi

    # Check for pull_request closed trigger
    if ! echo "$output" | grep -q "pull_request:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing pull_request trigger"
    fi

    if ! echo "$output" | grep -q "closed"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing closed event type"
    fi

    # Check for simplified PR-merge automation (issue closing instead of field updates)
    if ! echo "$output" | grep -q "closingIssuesReferences"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing closingIssuesReferences query"
    fi

    # Verify workflow uses gh issue close instead of GraphQL mutations
    if ! echo "$output" | grep -q "gh issue close"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should use 'gh issue close' for lifecycle management"
    fi

    # Verify updateProjectV2ItemFieldValue is NOT present (simplified workflow)
    if echo "$output" | grep -q "updateProjectV2ItemFieldValue"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should not use updateProjectV2ItemFieldValue (simplified to issue closing)"
    fi

    # Check for archive-pr-on-merge job
    if ! echo "$output" | grep -q "archive-pr-on-merge"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing archive-pr-on-merge job"
    fi

    # Check for archiveProjectV2Item mutation
    if ! echo "$output" | grep -q "archiveProjectV2Item"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing archiveProjectV2Item mutation"
    fi

    # Check for merged guard in archive job
    if ! echo "$output" | grep -q "github.event.pull_request.merged == true"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing merged guard for archive job"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "Automation template generated with enhanced lifecycle automation"
)
