#!/usr/bin/env bash
# Test: wt spawn with --yolo --no-agent creates worktree

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn with --yolo --no-agent creates worktree"

setup_test_repo
source ./wt-cli.sh

cmd_init

# Create worktree with --yolo --no-agent (should create worktree without invoking Claude)
cmd_create --yolo --no-agent 300

# Verify worktree was created
if [ ! -d "trees/issue-300" ]; then
    cleanup_test_repo
    test_fail "Worktree not created with --yolo --no-agent"
fi

cleanup_test_repo
test_pass "--yolo --no-agent creates worktree"
