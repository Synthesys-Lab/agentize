#!/usr/bin/env bash
# Test: wt spawn installs pre-commit hook in worktree

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn installs pre-commit hook in worktree"

setup_test_repo_with_precommit
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 200

# Verify hook was installed in the new worktree
HOOKS_DIR=$(git -C trees/issue-200 rev-parse --git-path hooks)
if [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    cleanup_test_repo
    test_fail "pre-commit hook not installed in wt spawn"
fi

cleanup_test_repo
test_pass "wt spawn installs pre-commit hook"
