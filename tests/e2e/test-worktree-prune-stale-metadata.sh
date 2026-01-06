#!/usr/bin/env bash
# Test: Prune stale metadata

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "Prune stale metadata"

setup_test_repo
source ./wt-cli.sh

cmd_init
cmd_prune

cleanup_test_repo
test_pass "Prune completed"
