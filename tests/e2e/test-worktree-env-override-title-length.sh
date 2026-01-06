#!/usr/bin/env bash
# Test: Metadata-driven default branch (trunk via .agentize.yaml)

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Metadata-driven default branch (trunk via .agentize.yaml)"

setup_test_repo_custom_branch "trunk"
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 100

# Verify worktree was created
if [ ! -d "trees/issue-100" ]; then
    cleanup_test_repo
    test_fail "Worktree not created with metadata-driven branch"
fi

# Verify it's based on trunk branch
BRANCH_BASE=$(git -C "trees/issue-100" log --oneline -1 2>/dev/null || echo "")
TRUNK_COMMIT=$(git log trunk --oneline -1 2>/dev/null || echo "")
if [ -n "$BRANCH_BASE" ] && [ -n "$TRUNK_COMMIT" ] && [[ "$BRANCH_BASE" != "$TRUNK_COMMIT" ]]; then
    cleanup_test_repo
    test_fail "Worktree not based on trunk branch"
fi

cleanup_test_repo
test_pass "Metadata-driven default branch works"
