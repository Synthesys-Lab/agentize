#!/usr/bin/env bash
# Test: Init mode without LANG parameter (should fail)

source "$(dirname "$0")/../common.sh"

test_info "Init mode without LANG parameter (should fail)"

TMP_DIR=$(make_temp_dir "makefile-init-no-lang")
OUTPUT_FILE="$TMP_DIR/output.txt"

# Run script without AGENTIZE_PROJECT_LANG in init mode
set +e
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    # Call without lang parameter - should fail
    lol_cmd_init "$TMP_DIR" "test_proj"
) > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify it failed
if [ $exit_code -ne 0 ]; then
    # Check error message mentions lang requirement
    if grep -q "project_lang is required" "$OUTPUT_FILE"; then
        cleanup_dir "$TMP_DIR"
        test_pass "Init mode correctly requires project_lang parameter"
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Error message doesn't mention project_lang requirement"
    fi
else
    cleanup_dir "$TMP_DIR"
    test_fail "Init mode should fail without project_lang, but succeeded"
fi
