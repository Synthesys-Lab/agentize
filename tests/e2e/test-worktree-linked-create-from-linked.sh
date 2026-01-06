#!/usr/bin/env bash
# Test: wt init installs pre-commit hook

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt init installs pre-commit hook"

# Test 1: Normal hook installation
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

# Test 2: Skip hook installation when core.hooksPath=/dev/null
setup_test_repo_with_precommit
git config core.hooksPath /dev/null
source ./wt-cli.sh

cmd_init

# Verify hook was NOT installed (skip /dev/null)
HOOKS_DIR=$(git -C trees/main rev-parse --git-path hooks)
if [ "$HOOKS_DIR" = "/dev/null" ]; then
    # Expected: /dev/null should not have a symlink created
    if [ -L "/dev/null/pre-commit" ]; then
        cleanup_test_repo
        test_fail "pre-commit hook should not be installed when core.hooksPath=/dev/null"
    fi
else
    cleanup_test_repo
    test_fail "Expected hooks path to be /dev/null when core.hooksPath=/dev/null"
fi

cleanup_test_repo
test_pass "wt init installs pre-commit hook"
