#!/usr/bin/env bash
# Test: Invalid issue number fails validation

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Invalid issue number fails validation"

setup_test_repo
source ./wt-cli.sh

cmd_init

if cmd_create --no-agent 999 2>/dev/null; then
    cleanup_test_repo
    test_fail "Should fail for invalid issue number"
fi

cleanup_test_repo
test_pass "Invalid issue validation works"
