#!/usr/bin/env bash
# Test: update mode with valid SDK structure (should succeed)

source "$(dirname "$0")/../common.sh"

test_info "update mode with valid SDK structure (should succeed)"

TMP_DIR=$(make_temp_dir "mode-test-update-valid-sdk")

# First creating a valid SDK
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_mode_6" "python"
)

# Modify a file in .claude/ to verify backup
echo "# Modified by test" >> "$TMP_DIR/.claude/settings.json"

# Now updating the SDK
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_update "$TMP_DIR"
)

# Verify backup was created
if [ ! -d "$TMP_DIR/.claude.backup" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Backup directory not created during update"
fi

# Verify settings.json was updated (shouldn't contain test modification)
if grep -q "Modified by test" "$TMP_DIR/.claude/settings.json"; then
    cleanup_dir "$TMP_DIR"
    test_fail "settings.json was not updated"
fi

# Verify backup contains the modification
if ! grep -q "Modified by test" "$TMP_DIR/.claude.backup/settings.json"; then
    cleanup_dir "$TMP_DIR"
    test_fail "Backup doesn't contain previous version"
fi

cleanup_dir "$TMP_DIR"
test_pass "update mode correctly updates valid SDK structure"
