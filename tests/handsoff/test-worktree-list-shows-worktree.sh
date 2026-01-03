#!/usr/bin/env bash
# Test: List worktrees

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "List worktrees"

setup_test_repo
source ./wt-cli.sh

cmd_init
cmd_create --no-agent 42

OUTPUT=$(cmd_list)
if [[ ! "$OUTPUT" =~ "issue-42" ]]; then
    cleanup_test_repo
    test_fail "Worktree not listed"
fi

cleanup_test_repo
test_pass "Worktree listed"
