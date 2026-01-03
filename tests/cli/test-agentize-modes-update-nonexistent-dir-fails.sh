#!/usr/bin/env bash
# Test: update mode with non-existent directory (should fail)

source "$(dirname "$0")/../common.sh"

test_info "update mode with non-existent directory (should fail)"

TMP_DIR=$(make_temp_dir "mode-test-update-nonexistent-dir-fails")
rm -rf "$TMP_DIR"

# Attempting to update non-existent directory (should fail)
if (
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    "$PROJECT_ROOT/scripts/agentize-update.sh"
) 2>&1 | grep -q "does not exist"; then
    test_pass "update mode correctly rejects non-existent directory"
else
    test_fail "update mode should have rejected non-existent directory"
fi
