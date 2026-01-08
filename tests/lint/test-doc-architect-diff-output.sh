#!/bin/bash
set -e

source "$(dirname "$0")/../common.sh"

# Test: doc-architect SKILL.md includes --diff mode documentation

test_info "Testing doc-architect skill for --diff mode support"

SKILL_FILE="$PROJECT_ROOT/.claude/skills/doc-architect/SKILL.md"

# Test case 1: skill includes --diff flag documentation
if ! grep -q "\-\-diff" "$SKILL_FILE"; then
    test_fail "doc-architect SKILL.md missing '--diff' flag documentation"
fi

# Test case 2: skill includes task list checkbox format
if ! grep -q "\- \[ \]" "$SKILL_FILE"; then
    test_fail "doc-architect SKILL.md missing task list checkbox format"
fi

# Test case 3: skill includes diff block example
if ! grep -q '` ` `diff' "$SKILL_FILE"; then
    test_fail "doc-architect SKILL.md missing diff block example"
fi

# Test case 4: skill mentions diff mode notes section
if ! grep -q "Diff mode notes" "$SKILL_FILE"; then
    test_fail "doc-architect SKILL.md missing 'Diff mode notes' section"
fi

test_pass "doc-architect skill includes --diff mode documentation"
