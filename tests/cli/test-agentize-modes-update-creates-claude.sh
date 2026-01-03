#!/usr/bin/env bash
# Test: update mode with directory without SDK structure (should create .claude/)

source "$(dirname "$0")/../common.sh"

test_info "update mode with directory without SDK structure (should create .claude/)"

TMP_DIR=$(make_temp_dir "mode-test-update-creates-claude")
touch "$TMP_DIR/some-file.txt"

# Updating directory without SDK structure (should create .claude/)
(
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    "$PROJECT_ROOT/scripts/agentize-update.sh"
)

# Verify .claude/ was created
if [ ! -d "$TMP_DIR/.claude" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail ".claude/ directory was not created"
fi

# Verify docs/git-msg-tags.md was created
if [ ! -f "$TMP_DIR/docs/git-msg-tags.md" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "docs/git-msg-tags.md was not created"
fi

# Verify no backup was created (since .claude/ didn't exist before)
if [ -d "$TMP_DIR/.claude.backup" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Backup should not be created when .claude/ is newly created"
fi

cleanup_dir "$TMP_DIR"
test_pass "update mode creates .claude/ and syncs files when missing"
