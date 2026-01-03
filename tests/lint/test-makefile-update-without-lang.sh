#!/usr/bin/env bash
# Test: Update mode without LANG parameter (should succeed)

source "$(dirname "$0")/../common.sh"

test_info "Update mode without LANG parameter (should succeed)"

TMP_DIR=$(make_temp_dir "makefile-update-no-lang")
OUTPUT_DIR=$(make_temp_dir "makefile-update-no-lang-output")
OUTPUT_FILE="$OUTPUT_DIR/output.txt"

# Setup: Create a valid SDK structure first
set +e
AGENTIZE_HOME="$PROJECT_ROOT" \
AGENTIZE_PROJECT_NAME="test_proj" \
AGENTIZE_PROJECT_PATH="$TMP_DIR" \
AGENTIZE_PROJECT_LANG="python" \
"$PROJECT_ROOT/scripts/agentize-init.sh" > "$OUTPUT_FILE" 2>&1
setup_exit=$?
set -e

if [ $setup_exit -ne 0 ]; then
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Setup failed: Could not create initial SDK structure"
fi

# Test: Update without LANG or NAME
set +e
AGENTIZE_HOME="$PROJECT_ROOT" \
AGENTIZE_PROJECT_PATH="$TMP_DIR" \
"$PROJECT_ROOT/scripts/agentize-update.sh" > "$OUTPUT_FILE" 2>&1
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
