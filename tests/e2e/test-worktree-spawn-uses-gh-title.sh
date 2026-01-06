#!/usr/bin/env bash
# Test: Create worktree with issue validation

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Create worktree with issue validation"

setup_test_repo
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 42

if [ ! -d "trees/issue-42" ]; then
    cleanup_test_repo
    test_fail "Worktree directory not created (expected: issue-42)"
fi

cleanup_test_repo
test_pass "Worktree created"
