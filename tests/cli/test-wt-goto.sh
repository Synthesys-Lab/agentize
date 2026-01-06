#!/usr/bin/env bash
# Test: wt goto changes directory to worktree targets

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

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

# Find the issue-42 directory (name includes title)
issue_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-42-*" | head -1)
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
