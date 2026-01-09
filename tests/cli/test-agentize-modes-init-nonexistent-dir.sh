#!/usr/bin/env bash
# Test: init mode with non-existent directory

source "$(dirname "$0")/../common.sh"

test_info "init mode with non-existent directory"

TMP_DIR=$(make_temp_dir "mode-test-init-nonexistent-dir")
rm -rf "$TMP_DIR"

# Creating SDK in non-existent directory
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_mode_1" "python"
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
