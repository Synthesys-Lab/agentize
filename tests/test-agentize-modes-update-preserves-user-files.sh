#!/usr/bin/env bash
# Test: update mode preserves user-added files

source "$(dirname "$0")/common.sh"

test_info "update mode preserves user-added custom files"

TMP_DIR=$(make_temp_dir "mode-test-update-preserves-user-files")

# First creating a valid SDK
(
    export AGENTIZE_PROJECT_NAME="test_mode_7"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    export AGENTIZE_PROJECT_LANG="python"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

# Add custom user files
mkdir -p "$TMP_DIR/.claude/skills/my-custom-skill"
echo "# My Custom Skill" > "$TMP_DIR/.claude/skills/my-custom-skill/SKILL.md"
mkdir -p "$TMP_DIR/.claude/commands/my-custom-command"
echo "# My Custom Command" > "$TMP_DIR/.claude/commands/my-custom-command/COMMAND.md"

# Running update to sync template files
(
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    "$PROJECT_ROOT/scripts/agentize-update.sh"
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
