#!/usr/bin/env bash
# Test: Status field verification auto-creates missing options

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

test_info "Status field verification auto-creates missing options"

TMP_DIR=$(make_temp_dir "lol-project-status-missing")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git remote add origin https://github.com/test-org/test-repo 2>/dev/null || true

    # Create a mock .agentize.yaml with project association
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 3
git:
  default_branch: main
EOF

    # Source the shared library
    source "$PROJECT_ROOT/src/cli/lol/project-lib.sh"

    # Test verify status options with missing fixture
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_GH_API="fixture"
    export AGENTIZE_GH_FIXTURE_LIST_FIELDS="missing"

    # Call project_verify_status_options
    output=$(project_verify_status_options "test-org" 3 2>&1)
    exit_code=$?

    # Check that missing options are detected and auto-creation is attempted
    if echo "$output" | grep -q "Missing required Status options" && \
       echo "$output" | grep -q "Refining" && \
       echo "$output" | grep -q "Plan Accepted"; then
        # Check that auto-creation is attempted
        if echo "$output" | grep -q "Creating missing options"; then
            # Check that creation succeeds (in fixture mode)
            if echo "$output" | grep -q "done" && \
               echo "$output" | grep -q "All missing Status options created successfully"; then
                cleanup_dir "$TMP_DIR"
                test_pass "Status verification auto-creates missing options"
            else
                cleanup_dir "$TMP_DIR"
                test_fail "Status verification should succeed in creating options (fixture mode)"
            fi
        else
            cleanup_dir "$TMP_DIR"
            test_fail "Status verification should attempt to create missing options"
        fi
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Status verification should detect missing options (Refining, Plan Accepted)"
    fi
)
