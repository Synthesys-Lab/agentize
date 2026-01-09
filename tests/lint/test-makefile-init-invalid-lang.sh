#!/usr/bin/env bash
# Test: Init mode with invalid LANG (should fail)

source "$(dirname "$0")/../common.sh"

test_info "Init mode with invalid LANG (should fail)"

TMP_DIR=$(make_temp_dir "makefile-invalid-lang")
OUTPUT_FILE="$TMP_DIR/output.txt"

# Run init with invalid language
set +e
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_proj" "rust"
) > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify it failed with appropriate error message
if [ $exit_code -ne 0 ]; then
    # Check error message mentions template not found
    if grep -qi "template.*not found\|invalid.*language" "$OUTPUT_FILE" || \
       grep -q "rust" "$OUTPUT_FILE"; then
        cleanup_dir "$TMP_DIR"
        test_pass "Init mode correctly rejects invalid language 'rust'"
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Error message doesn't clearly indicate template/language issue"
    fi
else
    cleanup_dir "$TMP_DIR"
    test_fail "Init mode should fail with invalid language, but succeeded"
fi
