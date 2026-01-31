#!/usr/bin/env bash
# Test: wt clone creates bare repo with trees/main

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

test_info "wt clone creates bare repo with trees/main"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

# Create a source repository to clone from
SEED_DIR=$(mktemp -d)
cd "$SEED_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "test content" > README.md
git add README.md
git commit -m "Initial commit"

# Create test directory for clone destination
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Source wt.sh to get the wt function
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# --------------------------------------------------
# Test 1: wt clone with explicit destination
# --------------------------------------------------
test_info "Test 1: wt clone with explicit destination"

dest_name="myrepo.git"
wt clone "$SEED_DIR" "$dest_name" >/dev/null 2>&1
clone_status=$?

if [ $clone_status -ne 0 ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone failed with exit code $clone_status"
fi

# Verify bare repo was created
if [ ! -d "$TEST_DIR/$dest_name" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Destination directory $dest_name was not created"
fi

# Verify it's a bare repo
if [ "$(git -C "$TEST_DIR/$dest_name" rev-parse --is-bare-repository)" != "true" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Cloned repository is not a bare repo"
fi

# Verify trees/main was created
if [ ! -d "$TEST_DIR/$dest_name/trees/main" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "trees/main was not created in $dest_name"
fi

# Verify README.md exists in trees/main (worktree content)
if [ ! -f "$TEST_DIR/$dest_name/trees/main/README.md" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "README.md not found in trees/main"
fi

# --------------------------------------------------
# Test 1b: Verify refspec and prune config after clone
# --------------------------------------------------
test_info "Test 1b: Verify refspec and prune config after clone"

# Check remote.origin.fetch is set correctly
refspec=$(git -C "$TEST_DIR/$dest_name" config --get remote.origin.fetch 2>/dev/null)
if [ "$refspec" != "+refs/heads/*:refs/remotes/origin/*" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "remote.origin.fetch not set correctly: got '$refspec'"
fi

# Check fetch.prune is enabled
prune_setting=$(git -C "$TEST_DIR/$dest_name" config --get fetch.prune 2>/dev/null)
if [ "$prune_setting" != "true" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "fetch.prune not set to true: got '$prune_setting'"
fi

# --------------------------------------------------
# Test 2: wt clone infers destination from URL
# --------------------------------------------------
test_info "Test 2: wt clone infers destination from URL"

# Return to TEST_DIR first (clone changes directory)
cd "$TEST_DIR"

# Use a path ending with .git to test inference
wt clone "$SEED_DIR" >/dev/null 2>&1
clone_status=$?

# Expected destination: basename of SEED_DIR + .git
expected_base=$(basename "$SEED_DIR")
expected_dest="${expected_base}.git"

if [ $clone_status -ne 0 ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone (inferred dest) failed with exit code $clone_status"
fi

if [ ! -d "$TEST_DIR/$expected_dest" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Inferred destination $expected_dest was not created"
fi

if [ ! -d "$TEST_DIR/$expected_dest/trees/main" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "trees/main was not created in inferred dest $expected_dest"
fi

# --------------------------------------------------
# Test 3: wt clone fails if destination exists
# --------------------------------------------------
test_info "Test 3: wt clone fails if destination exists"

# Return to TEST_DIR first
cd "$TEST_DIR"

mkdir -p "$TEST_DIR/existing.git"
if wt clone "$SEED_DIR" "existing.git" >/dev/null 2>&1; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone should fail when destination already exists"
fi

# --------------------------------------------------
# Test 4: wt clone fails without URL
# --------------------------------------------------
test_info "Test 4: wt clone fails without URL"

if wt clone 2>/dev/null; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone should fail when no URL provided"
fi

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
rm -rf "$SEED_DIR" "$TEST_DIR"
test_pass "wt clone creates bare repo with trees/main"
