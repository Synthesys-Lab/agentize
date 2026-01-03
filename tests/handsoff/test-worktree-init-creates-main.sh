#!/usr/bin/env bash
# Test: wt init creates trees/main worktree

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "init creates trees/main worktree"

setup_test_repo
source ./wt-cli.sh

cmd_init

if [ ! -d "trees/main" ]; then
    cleanup_test_repo
    test_fail "trees/main directory not created"
fi

# Verify it's on main branch
BRANCH=$(git -C trees/main branch --show-current)
if [[ "$BRANCH" != "main" ]] && [[ "$BRANCH" != "master" ]]; then
    cleanup_test_repo
    test_fail "trees/main not on main/master branch (got: $BRANCH)"
fi

cleanup_test_repo
test_pass "init created trees/main"
