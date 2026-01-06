#!/usr/bin/env bash
# Test: wt spawn requires init (trees/main must exist)

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "spawn requires init (trees/main must exist)"

setup_test_repo
source ./wt-cli.sh

# Try to spawn without init (trees/main missing)
if cmd_create --no-agent 99 2>/dev/null; then
    cleanup_test_repo
    test_fail "spawn should fail when trees/main is missing"
fi

cleanup_test_repo
test_pass "spawn correctly requires init"
