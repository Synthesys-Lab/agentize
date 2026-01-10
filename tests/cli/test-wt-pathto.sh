#!/usr/bin/env bash
# Test: wt pathto prints worktree paths

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt pathto prints worktree paths"

setup_test_repo
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Test: wt pathto main returns trees/main path
output=$(wt pathto main 2>/dev/null)
expected_path="$TEST_REPO_DIR/trees/main"

if [ "$output" != "$expected_path" ]; then
  cleanup_test_repo
  test_fail "wt pathto main failed: expected $expected_path, got $output"
fi

# Verify exit code is 0
if ! wt pathto main >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto main should exit 0"
fi

# Create a worktree for issue-42
wt spawn 42 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 42 failed"

# Test: wt pathto 42 returns issue-42 path
output=$(wt pathto 42 2>/dev/null)

# Find the actual issue-42 directory
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "Could not find issue-42 worktree directory"
fi

if [ "$output" != "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "wt pathto 42 failed: expected $issue_dir, got $output"
fi

# Verify exit code is 0 for existing worktree
if ! wt pathto 42 >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto 42 should exit 0 for existing worktree"
fi

# Test: wt pathto with non-existent issue should fail (exit 1)
if wt pathto 999 >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto 999 should exit non-zero for non-existent worktree"
fi

# Test: wt pathto without argument should fail
if wt pathto >/dev/null 2>&1; then
  cleanup_test_repo
  test_fail "wt pathto without argument should exit non-zero"
fi

cleanup_test_repo
test_pass "wt pathto correctly prints worktree paths"
