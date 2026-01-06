#!/usr/bin/env bash
# Test: Legacy worktree removal

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Legacy worktree removal"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Manually create a legacy-named worktree
git worktree add trees/issue-88-legacy-name -b issue-88-legacy-name

# Verify it was created
if [ ! -d "trees/issue-88-legacy-name" ]; then
    cleanup_test_repo
    test_fail "Failed to create legacy worktree for testing"
fi

# Remove using cmd_remove with issue number
cmd_remove 88

# Verify legacy worktree was removed
if [ -d "trees/issue-88-legacy-name" ]; then
    cleanup_test_repo
    test_fail "Legacy worktree not removed"
fi

# Verify branch was deleted
if git branch | grep -q "issue-88-legacy-name"; then
    cleanup_test_repo
    test_fail "Legacy branch not removed"
fi

cleanup_test_repo
test_pass "Legacy worktree removal works"
