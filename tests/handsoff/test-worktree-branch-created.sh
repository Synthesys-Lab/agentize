#!/usr/bin/env bash
# Test: Verify branch exists

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Verify branch exists"

setup_test_repo
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 42

if ! git branch | grep -q "issue-42"; then
    cleanup_test_repo
    test_fail "Branch not created"
fi

cleanup_test_repo
test_pass "Branch created"
