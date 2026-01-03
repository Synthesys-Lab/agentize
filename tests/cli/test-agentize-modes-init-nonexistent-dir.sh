#!/usr/bin/env bash
# Test: init mode with non-existent directory

source "$(dirname "$0")/../common.sh"

test_info "init mode with non-existent directory"

TMP_DIR=$(make_temp_dir "mode-test-init-nonexistent-dir")
rm -rf "$TMP_DIR"

# Creating SDK in non-existent directory
(
    export AGENTIZE_PROJECT_NAME="test_mode_1"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    export AGENTIZE_PROJECT_LANG="python"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

if [ ! -d "$TMP_DIR" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Directory was not created"
fi

if [ ! -d "$TMP_DIR/.claude" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "SDK structure not created"
fi

cleanup_dir "$TMP_DIR"
test_pass "init mode creates directory and SDK structure"
