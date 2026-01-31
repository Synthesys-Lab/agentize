#!/usr/bin/env bash
# Test: lol project --automation configures Status field

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

test_info "lol project --automation configures default Status field"

TMP_DIR=$(make_temp_dir "lol-project-auto-field")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Add org and id to metadata
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 42
git:
  default_branch: main
EOF

    # Test with fixture mode (simulates API calls)
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="automation"
    export AGENTIZE_PROJECT_WRITE_PATH=".github/workflows/project.yml"
    export AGENTIZE_GH_API="fixture"

    # Run automation command
    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Check that Status field was configured
    if ! echo "$output" | grep -q "Configuring Status field"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation should attempt to configure Status field"
    fi

    # Check that workflow file was created
    if [ ! -f ".github/workflows/project.yml" ]; then
        cleanup_dir "$TMP_DIR"
        test_fail "Workflow file not created"
    fi

    # Read the generated workflow file
    workflow_content=$(cat ".github/workflows/project.yml")

    # Verify STAGE_FIELD_ID is NOT present (uses Status field by name)
    if echo "$workflow_content" | grep -q "STAGE_FIELD_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "STAGE_FIELD_ID should not be present (uses Status field by name)"
    fi

    # Verify workflow uses status-field: Status and status-value: Proposed
    if ! echo "$workflow_content" | grep -q "status-field: Status"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Workflow should use status-field: Status"
    fi

    if ! echo "$workflow_content" | grep -q "status-value: Proposed"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Workflow should use status-value: Proposed"
    fi

    # Verify org and id are filled
    if ! echo "$workflow_content" | grep -q "PROJECT_ORG: test-org"; then
        cleanup_dir "$TMP_DIR"
        test_fail "PROJECT_ORG not substituted"
    fi

    if ! echo "$workflow_content" | grep -q "PROJECT_ID: 42"; then
        cleanup_dir "$TMP_DIR"
        test_fail "PROJECT_ID not substituted"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "Status field configured successfully"
)
