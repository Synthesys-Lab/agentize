#!/usr/bin/env bash
# Test: Linked worktree - create worktree from linked worktree

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Linked worktree - create worktree from linked worktree"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Create first worktree
cmd_create --no-agent 55

# cd into the linked worktree
cd trees/issue-55

# Source wt-cli.sh again in the linked worktree context
source "$TEST_REPO_DIR/wt-cli.sh"

# Try to create another worktree from inside the linked worktree
# It should create the new worktree under the main repo root, not inside the linked worktree
cmd_create --no-agent 56

# Verify the new worktree is created under main repo root
if [ ! -d "$TEST_REPO_DIR/trees/issue-56" ]; then
    cd "$TEST_REPO_DIR"
    cleanup_test_repo
    test_fail "Worktree not created under main repo root"
fi

# Verify it's NOT created inside the linked worktree
if [ -d "trees/issue-56" ]; then
    cd "$TEST_REPO_DIR"
    cleanup_test_repo
    test_fail "Worktree incorrectly created inside linked worktree"
fi

cd "$TEST_REPO_DIR"
cleanup_test_repo
test_pass "Linked worktree creates under main repo root"
