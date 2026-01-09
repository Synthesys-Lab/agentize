#!/usr/bin/env bash
# Test: update mode preserves user-added files

source "$(dirname "$0")/../common.sh"

test_info "update mode preserves user-added custom files"

TMP_DIR=$(make_temp_dir "mode-test-update-preserves-user-files")

# First creating a valid SDK
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_mode_7" "python"
)

# Add custom user files
mkdir -p "$TMP_DIR/.claude/skills/my-custom-skill"
echo "# My Custom Skill" > "$TMP_DIR/.claude/skills/my-custom-skill/SKILL.md"
mkdir -p "$TMP_DIR/.claude/commands/my-custom-command"
echo "# My Custom Command" > "$TMP_DIR/.claude/commands/my-custom-command/COMMAND.md"

# Running update to sync template files
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_update "$TMP_DIR"
)

# Verify custom user files still exist
if [ ! -f "$TMP_DIR/.claude/skills/my-custom-skill/SKILL.md" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Custom skill file was deleted during update"
fi

if [ ! -f "$TMP_DIR/.claude/commands/my-custom-command/COMMAND.md" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Custom command file was deleted during update"
fi

# Verify template files were updated correctly (settings.json should exist)
if [ ! -f "$TMP_DIR/.claude/settings.json" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "Template file settings.json was not updated"
fi

cleanup_dir "$TMP_DIR"
test_pass "update mode preserves user-added files while updating templates"
