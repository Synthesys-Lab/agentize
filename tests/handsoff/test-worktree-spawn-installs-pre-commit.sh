#!/usr/bin/env bash
# Test: Force delete with --force flag

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Force delete with --force flag"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Create another worktree with an unmerged commit
cmd_create --no-agent 211

# Create an unmerged commit
cd "trees/issue-211"
echo "force test content" > force.txt
git add force.txt
git commit -m "Force test commit"
cd "$TEST_REPO_DIR"

# Try force delete with --force flag
cmd_remove --force 211

# Verify worktree was removed
if [ -d "trees/issue-211" ]; then
    cleanup_test_repo
    test_fail "Worktree still exists after --force removal"
fi

# Verify branch was force-deleted
if git branch | grep -q "issue-211"; then
    cleanup_test_repo
    test_fail "Branch still exists after --force removal"
fi

cleanup_test_repo
test_pass "--force flag works for branch deletion"
