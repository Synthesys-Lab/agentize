#!/usr/bin/env bash
# Test: wt spawn claims issue status as "In Progress" via GitHub Projects API

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
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn claims issue status as In Progress"

# Custom setup that includes .agentize.yaml and git remote in seed repo
setup_test_repo_with_project_config() {
    clean_git_env

    # Create temp directory for seed repo
    local SEED_DIR=$(mktemp -d)
    cd "$SEED_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit with .agentize.yaml
    echo "test" > README.md
    cat > .agentize.yaml <<'EOF'
project:
  org: test-org
  id: 3
EOF
    git add README.md .agentize.yaml
    git commit -m "Initial commit with project config"

    # Add a fake origin remote (needed for repo parsing)
    git remote add origin https://github.com/test-org/test-repo.git

    # Clone as bare repo
    TEST_REPO_DIR=$(mktemp -d)
    git clone --bare "$SEED_DIR" "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"

    # Set origin remote to GitHub URL (clone --bare sets it to the local seed dir)
    git remote set-url origin https://github.com/test-org/test-repo.git

    # Clean up seed repo
    rm -rf "$SEED_DIR"

    # Copy src/cli/wt.sh as wt-cli.sh for test sourcing
    cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh

    # Copy wt/ module directory for modular loading
    cp -r "$PROJECT_ROOT/src/cli/wt" ./wt

    # Copy scripts/gh-graphql.sh for fixture mode
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/gh-graphql.sh" ./scripts/gh-graphql.sh
    chmod +x ./scripts/gh-graphql.sh

    # Copy test fixtures
    mkdir -p tests/fixtures/github-projects
    cp "$PROJECT_ROOT/tests/fixtures/github-projects/"*.json ./tests/fixtures/github-projects/

    # Create gh stub for testing
    create_gh_stub
}

setup_test_repo_with_project_config
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Enable fixture mode for gh-graphql.sh
export AGENTIZE_GH_API=fixture

# Spawn worktree for issue 42 (no agent to avoid Claude invocation)
cd "$TEST_REPO_DIR"
spawn_output=$(wt spawn 42 --no-agent 2>&1)
spawn_exit=$?

if [ $spawn_exit -ne 0 ]; then
  cleanup_test_repo
  test_fail "wt spawn 42 failed with exit code $spawn_exit: $spawn_output"
fi

# Verify worktree was created
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "issue-42 worktree was not created"
fi

# Verify status claim message appears in output
if ! echo "$spawn_output" | grep -qi "in progress"; then
  echo "DEBUG: spawn_output = $spawn_output" >&2
  cleanup_test_repo
  test_fail "spawn output should mention status update to In Progress"
fi

# Test: spawn still succeeds when project config is missing
# First, create a repo without .agentize.yaml
setup_test_repo
source ./wt-cli.sh
wt init >/dev/null 2>&1 || test_fail "wt init failed for second repo"

cd "$TEST_REPO_DIR"
spawn_output=$(wt spawn 55 --no-agent 2>&1)
spawn_exit=$?

if [ $spawn_exit -ne 0 ]; then
  cleanup_test_repo
  test_fail "wt spawn should succeed even without project config"
fi

# Verify worktree was created
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-55*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "issue-55 worktree was not created"
fi

cleanup_test_repo
test_pass "wt spawn correctly claims issue status"
