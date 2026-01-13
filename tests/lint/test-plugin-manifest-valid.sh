#!/usr/bin/env bash
# Test: Plugin manifest validation

source "$(dirname "$0")/../common.sh"

test_info "Plugin manifest validation"

PLUGIN_JSON="$PROJECT_ROOT/.claude-plugin/plugin.json"

# Check plugin.json exists
if [ ! -f "$PLUGIN_JSON" ]; then
    test_fail "Plugin manifest not found at $PLUGIN_JSON"
fi

# Validate JSON syntax
if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
    test_fail "Plugin manifest has invalid JSON syntax"
fi

# Check required field: name
NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
if [ -z "$NAME" ]; then
    test_fail "Plugin manifest missing required field: name"
fi

# Validate referenced paths exist
COMMANDS_PATH=$(jq -r '.commands // empty' "$PLUGIN_JSON")
if [ -n "$COMMANDS_PATH" ]; then
    COMMANDS_DIR="$PROJECT_ROOT/${COMMANDS_PATH#./}"
    if [ ! -d "$COMMANDS_DIR" ]; then
        test_fail "Commands directory not found: $COMMANDS_DIR"
    fi
fi

SKILLS_PATH=$(jq -r '.skills // empty' "$PLUGIN_JSON")
if [ -n "$SKILLS_PATH" ]; then
    SKILLS_DIR="$PROJECT_ROOT/${SKILLS_PATH#./}"
    if [ ! -d "$SKILLS_DIR" ]; then
        test_fail "Skills directory not found: $SKILLS_DIR"
    fi
fi

AGENTS_PATH=$(jq -r '.agents // empty' "$PLUGIN_JSON")
if [ -n "$AGENTS_PATH" ]; then
    AGENTS_DIR="$PROJECT_ROOT/${AGENTS_PATH#./}"
    if [ ! -d "$AGENTS_DIR" ]; then
        test_fail "Agents directory not found: $AGENTS_DIR"
    fi
fi

HOOKS_PATH=$(jq -r '.hooks // empty' "$PLUGIN_JSON")
if [ -n "$HOOKS_PATH" ]; then
    HOOKS_FILE="$PROJECT_ROOT/${HOOKS_PATH#./}"
    if [ ! -f "$HOOKS_FILE" ]; then
        test_fail "Hooks file not found: $HOOKS_FILE"
    fi
fi

test_pass "Plugin manifest is valid with name='$NAME'"
