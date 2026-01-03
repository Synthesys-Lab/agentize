#!/usr/bin/env bash
# Test: Update mode infers LANG from existing structure

source "$(dirname "$0")/../common.sh"

test_info "Update mode infers LANG from existing structure"

TMP_DIR=$(make_temp_dir "makefile-infer-lang")
OUTPUT_DIR=$(make_temp_dir "makefile-infer-lang-output")
OUTPUT_FILE="$OUTPUT_DIR/output.txt"

# Setup: Create Python SDK
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

# Remove git-msg-tags.md to trigger recreation with language detection
rm -f "$TMP_DIR/docs/git-msg-tags.md"

# Test: Update without LANG should infer Python from structure
set +e
AGENTIZE_HOME="$PROJECT_ROOT" \
AGENTIZE_PROJECT_PATH="$TMP_DIR" \
"$PROJECT_ROOT/scripts/agentize-update.sh" > "$OUTPUT_FILE" 2>&1
exit_code=$?
set -e

# Verify Python template was used
if [ $exit_code -eq 0 ] && [ -f "$TMP_DIR/docs/git-msg-tags.md" ]; then
    # Python template should have `deps` but not `build`
    if grep -q '`deps`' "$TMP_DIR/docs/git-msg-tags.md" && ! grep -q '`build`' "$TMP_DIR/docs/git-msg-tags.md"; then
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_pass "Update mode correctly inferred Python and used Python template"
    else
        cleanup_dir "$TMP_DIR"
        cleanup_dir "$OUTPUT_DIR"
        test_fail "Wrong template used (expected Python template with deps, no build)"
    fi
else
    cleanup_dir "$TMP_DIR"
    cleanup_dir "$OUTPUT_DIR"
    test_fail "Update mode did not recreate git-msg-tags.md with language inference"
fi
