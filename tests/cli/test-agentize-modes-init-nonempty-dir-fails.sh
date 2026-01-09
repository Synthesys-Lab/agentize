#!/usr/bin/env bash
# Test: init mode with non-empty existing directory (should fail)

source "$(dirname "$0")/../common.sh"

test_info "init mode with non-empty existing directory (should fail)"

TMP_DIR=$(make_temp_dir "mode-test-init-nonempty-dir-fails")
touch "$TMP_DIR/existing-file.txt"

# Attempting to create SDK in non-empty directory (should fail)
if (
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_mode_3" "python"
) 2>&1 | grep -q "exists and is not empty"; then
    cleanup_dir "$TMP_DIR"
    test_pass "init mode correctly rejects non-empty directory"
else
    cleanup_dir "$TMP_DIR"
    test_fail "init mode should have rejected non-empty directory"
fi
