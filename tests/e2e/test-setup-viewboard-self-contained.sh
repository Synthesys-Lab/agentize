#!/usr/bin/env bash
# Test: /setup-viewboard command is self-contained and does not call lol project

source "$(dirname "$0")/../common.sh"

test_info "/setup-viewboard command is self-contained (no lol project calls)"

COMMAND_FILE="$PROJECT_ROOT/.claude-plugin/commands/setup-viewboard.md"

# Verify the command file exists
if [ ! -f "$COMMAND_FILE" ]; then
    test_fail "setup-viewboard.md command file not found"
fi

# Check that the command file does NOT contain 'lol project' invocations
# We check for patterns that indicate lol project usage
if grep -q 'lol project --create' "$COMMAND_FILE" || \
   grep -q 'lol project --associate' "$COMMAND_FILE" || \
   grep -q 'lol project --automation' "$COMMAND_FILE"; then
    test_fail "setup-viewboard.md still contains 'lol project' command calls"
fi

# Check that the command file contains project_* function references (from shared library)
if ! grep -q 'project_create\|project_associate\|project_generate_automation' "$COMMAND_FILE"; then
    test_fail "setup-viewboard.md should reference shared library functions (project_create, project_associate, project_generate_automation)"
fi

# Check that the command file contains project_verify_status_options reference
if ! grep -q 'project_verify_status_options' "$COMMAND_FILE"; then
    test_fail "setup-viewboard.md should reference project_verify_status_options for Status field verification"
fi

test_pass "/setup-viewboard is self-contained using shared project library"
