#!/usr/bin/env bash
# Test: Update mode preserves existing git-msg-tags.md

source "$(dirname "$0")/../common.sh"

test_info "Update mode preserves existing git-msg-tags.md"

TMP_DIR=$(make_temp_dir "makefile-update-preserve-tags")
OUTPUT_DIR=$(make_temp_dir "makefile-update-preserve-tags-output")
OUTPUT_FILE="$OUTPUT_DIR/output.txt"

# Setup: Create SDK structure
set +e
AGENTIZE_HOME="$PROJECT_ROOT" \
AGENTIZE_PROJECT_NAME="test_proj" \
AGENTIZE_PROJECT_PATH="$TMP_DIR" \
AGENTIZE_PROJECT_LANG="c" \
"$PROJECT_ROOT/scripts/agentize-init.sh" > "$OUTPUT_FILE" 2>&1
setup_exit=$?
set -e

if [ $setup_exit -ne 0 ]; then
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Setup failed: Could not create initial SDK structure"
fi

# Modify git-msg-tags.md with custom content
echo "# Custom tags - DO NOT OVERWRITE" > "$TMP_DIR/docs/git-msg-tags.md"
echo "custom-tag: Custom modification description" >> "$TMP_DIR/docs/git-msg-tags.md"

# Test: Update should preserve custom content
set +e
AGENTIZE_HOME="$PROJECT_ROOT" \
AGENTIZE_PROJECT_PATH="$TMP_DIR" \
"$PROJECT_ROOT/scripts/agentize-update.sh" > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify custom content is preserved
if [ $exit_code -eq 0 ] && grep -q "# Custom tags - DO NOT OVERWRITE" "$TMP_DIR/docs/git-msg-tags.md"; then
    if grep -q "custom-tag:" "$TMP_DIR/docs/git-msg-tags.md"; then
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_pass "Update mode preserved custom git-msg-tags.md content"
    else
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_fail "Custom content partially lost"
    fi
else
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Update mode did not preserve existing git-msg-tags.md"
fi
