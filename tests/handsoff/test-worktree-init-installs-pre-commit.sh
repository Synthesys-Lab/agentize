#!/usr/bin/env bash
# Test: Force delete unmerged branch with -D flag

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Force delete unmerged branch with -D flag"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Create a worktree with an unmerged commit
cmd_create --no-agent 210

# Create an unmerged commit in the worktree
cd "trees/issue-210"
echo "unmerged content" > unmerged.txt
git add unmerged.txt
git commit -m "Unmerged commit"
cd "$TEST_REPO_DIR"

# Try force delete with -D flag
cmd_remove -D 210

# Verify worktree was removed
if [ -d "trees/issue-210" ]; then
    cleanup_test_repo
    test_fail "Worktree still exists after force removal"
fi

# Verify branch was force-deleted
if git branch | grep -q "issue-210"; then
    cleanup_test_repo
    test_fail "Branch still exists after force removal"
fi

cleanup_test_repo
test_pass "Force delete removed unmerged branch"
