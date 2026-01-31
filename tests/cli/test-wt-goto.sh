#!/usr/bin/env bash
# Test: wt goto changes directory to worktree targets

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

source "$SCRIPT_DIR/../helpers-worktree.sh"

test_info "wt goto changes directory to worktree targets"

setup_test_repo
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Verify trees/main was created
if [ ! -d "trees/main" ]; then
  cleanup_test_repo
  test_fail "trees/main was not created by wt init"
fi

# Verify refspec and prune config after init (when origin exists)
# The test repo created by helpers-worktree.sh has an origin remote from clone
if git remote get-url origin >/dev/null 2>&1; then
  refspec=$(git config --get remote.origin.fetch 2>/dev/null)
  if [ "$refspec" != "+refs/heads/*:refs/remotes/origin/*" ]; then
    cleanup_test_repo
    test_fail "remote.origin.fetch not set correctly after init: got '$refspec'"
  fi

  prune_setting=$(git config --get fetch.prune 2>/dev/null)
  if [ "$prune_setting" != "true" ]; then
    cleanup_test_repo
    test_fail "fetch.prune not set to true after init: got '$prune_setting'"
  fi
fi

# Test: wt goto main
cd "$TEST_REPO_DIR"
wt goto main 2>/dev/null
current_dir=$(pwd)
expected_dir="$TEST_REPO_DIR/trees/main"

if [ "$current_dir" != "$expected_dir" ]; then
  cleanup_test_repo
  test_fail "wt goto main failed: expected $expected_dir, got $current_dir"
fi

# Create a worktree for issue-42
cd "$TEST_REPO_DIR"
wt spawn 42 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 42 failed"

# Test: wt goto 42
cd "$TEST_REPO_DIR"
wt goto 42 2>/dev/null
current_dir=$(pwd)

# Find the issue-42 directory (matches both "issue-42" and "issue-42-title")
issue_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "Could not find issue-42 worktree directory"
fi

if [ "$current_dir" != "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "wt goto 42 failed: expected $issue_dir, got $current_dir"
fi

# Test: wt goto with non-existent issue should fail gracefully
cd "$TEST_REPO_DIR"
if wt goto 999 2>/dev/null; then
  cleanup_test_repo
  test_fail "wt goto 999 should fail for non-existent worktree"
fi

cleanup_test_repo
test_pass "wt goto correctly changes directory to worktree targets"
