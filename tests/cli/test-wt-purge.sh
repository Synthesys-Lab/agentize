#!/usr/bin/env bash
# Test: wt purge removes worktrees for closed GitHub issues

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt purge removes worktrees for closed GitHub issues"

setup_test_repo
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Create worktrees for both open and closed issues
# Open issues: 42, 55
# Closed issues: 56, 211 (per gh stub in helpers-worktree.sh)

cd "$TEST_REPO_DIR"
wt spawn 42 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 42 failed"
wt spawn 55 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 55 failed"
wt spawn 56 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 56 failed"
wt spawn 211 --no-agent >/dev/null 2>&1 || test_fail "wt spawn 211 failed"

# Verify all worktrees were created
if [ ! -d "trees/issue-42-"* ]; then
  cleanup_test_repo
  test_fail "issue-42 worktree was not created"
fi
if [ ! -d "trees/issue-55-"* ]; then
  cleanup_test_repo
  test_fail "issue-55 worktree was not created"
fi
if [ ! -d "trees/issue-56-"* ]; then
  cleanup_test_repo
  test_fail "issue-56 worktree was not created"
fi
if [ ! -d "trees/issue-211-"* ]; then
  cleanup_test_repo
  test_fail "issue-211 worktree was not created"
fi

# Run wt purge
cd "$TEST_REPO_DIR"
purge_output=$(wt purge 2>&1)

# Verify closed issues were removed (56, 211)
# Check output messages
if ! echo "$purge_output" | grep -q "issue-56"; then
  cleanup_test_repo
  test_fail "purge output should mention issue-56"
fi

if ! echo "$purge_output" | grep -q "issue-211"; then
  cleanup_test_repo
  test_fail "purge output should mention issue-211"
fi

# Verify closed issue worktrees were removed
issue_56_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-56-*" 2>/dev/null | head -1)
if [ -n "$issue_56_dir" ]; then
  cleanup_test_repo
  test_fail "issue-56 worktree should be removed after purge"
fi

issue_211_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-211-*" 2>/dev/null | head -1)
if [ -n "$issue_211_dir" ]; then
  cleanup_test_repo
  test_fail "issue-211 worktree should be removed after purge"
fi

# Verify open issue worktrees still exist (42, 55)
issue_42_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-42-*" 2>/dev/null | head -1)
if [ -z "$issue_42_dir" ]; then
  cleanup_test_repo
  test_fail "issue-42 worktree should still exist after purge"
fi

issue_55_dir=$(find "$TEST_REPO_DIR/trees" -type d -name "issue-55-*" 2>/dev/null | head -1)
if [ -z "$issue_55_dir" ]; then
  cleanup_test_repo
  test_fail "issue-55 worktree should still exist after purge"
fi

cleanup_test_repo
test_pass "wt purge correctly removes worktrees for closed issues"
