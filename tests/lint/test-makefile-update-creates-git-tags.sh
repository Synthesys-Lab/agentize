#!/usr/bin/env bash
# Test: Update mode creates missing git-msg-tags.md

source "$(dirname "$0")/../common.sh"

test_info "Update mode creates missing git-msg-tags.md"

TMP_DIR=$(make_temp_dir "makefile-update-git-tags")
OUTPUT_DIR=$(make_temp_dir "makefile-update-git-tags-output")
OUTPUT_FILE="$OUTPUT_DIR/output.txt"

# Setup: Create SDK structure
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

# Remove git-msg-tags.md
rm -f "$TMP_DIR/docs/git-msg-tags.md"

# Test: Update should recreate the file
set +e
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_update "$TMP_DIR"
) > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify file was created
if [ $exit_code -eq 0 ] && [ -f "$TMP_DIR/docs/git-msg-tags.md" ]; then
    # Check for Python-specific content (deps tag) and absence of C/C++ build tag
    if grep -q '`deps`' "$TMP_DIR/docs/git-msg-tags.md" && ! grep -q '`build`' "$TMP_DIR/docs/git-msg-tags.md"; then
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_pass "Update mode recreated git-msg-tags.md with Python-specific content"
    else
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_fail "git-msg-tags.md was created but lacks Python-specific content"
    fi
else
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Update mode did not recreate missing git-msg-tags.md"
fi
