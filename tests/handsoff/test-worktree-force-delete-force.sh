#!/usr/bin/env bash
# Test: Flag after issue number (--no-agent <issue> --yolo)

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Flag after issue number (--no-agent <issue> --yolo)"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Create worktree with --no-agent --yolo <issue>
# This test verifies flags work in any position
cmd_create --no-agent 301 --yolo

# Verify worktree was created with correct name
if [ ! -d "trees/issue-301" ]; then
    cleanup_test_repo
    test_fail "Worktree not created with correct name (expected: issue-301)"
fi

cleanup_test_repo
test_pass "Flag after issue number handled correctly"
