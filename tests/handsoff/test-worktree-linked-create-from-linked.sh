#!/usr/bin/env bash
# Test: wt init installs pre-commit hook

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt init installs pre-commit hook"

setup_test_repo_with_precommit
source ./wt-cli.sh

cmd_init

# Verify hook was installed in main worktree
HOOKS_DIR=$(git -C trees/main rev-parse --git-path hooks)
if [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    cleanup_test_repo
    test_fail "pre-commit hook not installed in wt init"
fi

cleanup_test_repo
test_pass "wt init installs pre-commit hook"
