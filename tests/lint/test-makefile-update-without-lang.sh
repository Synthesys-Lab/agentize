#!/usr/bin/env bash
# Test: Update mode without LANG parameter (should succeed)

source "$(dirname "$0")/../common.sh"

test_info "Update mode without LANG parameter (should succeed)"

TMP_DIR=$(make_temp_dir "makefile-update-no-lang")
OUTPUT_DIR=$(make_temp_dir "makefile-update-no-lang-output")
OUTPUT_FILE="$OUTPUT_DIR/output.txt"

# Setup: Create a valid SDK structure first
set +e
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_proj" "python"
) > "$OUTPUT_FILE" 2>&1
setup_exit=$?
set -e

if [ $setup_exit -ne 0 ]; then
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Setup failed: Could not create initial SDK structure"
fi

# Test: Update without LANG or NAME
set +e
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_update "$TMP_DIR"
) > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify it succeeded
if [ $exit_code -eq 0 ]; then
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_pass "Update mode succeeded without AGENTIZE_PROJECT_LANG or NAME"
else
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Update mode should succeed without LANG/NAME, but failed"
fi
