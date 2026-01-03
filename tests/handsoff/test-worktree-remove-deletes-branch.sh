#!/usr/bin/env bash
# Test: Remove worktree and verify branch deletion

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Remove worktree and verify branch deletion"

setup_test_repo
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 42
cmd_remove 42

if [ -d "trees/issue-42" ]; then
    cleanup_test_repo
    test_fail "Worktree directory still exists"
fi

# Verify branch was deleted
if git branch | grep -q "issue-42"; then
    cleanup_test_repo
    test_fail "Branch still exists after removal"
fi

cleanup_test_repo
test_pass "Worktree and branch removed"
