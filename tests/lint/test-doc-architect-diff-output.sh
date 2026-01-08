#!/bin/bash
set -e

# Test: doc-architect SKILL.md includes --diff mode documentation

echo "Testing doc-architect skill for --diff mode support..."

SKILL_FILE=".claude/skills/doc-architect/SKILL.md"

# Test case 1: skill includes --diff flag documentation
if ! grep -q "\-\-diff" "$SKILL_FILE"; then
    echo "FAIL: doc-architect SKILL.md missing '--diff' flag documentation"
    exit 1
fi

# Test case 2: skill includes task list checkbox format
if ! grep -q "\- \[ \]" "$SKILL_FILE"; then
    echo "FAIL: doc-architect SKILL.md missing task list checkbox format"
    exit 1
fi

# Test case 3: skill includes diff block example
if ! grep -q '` ` `diff' "$SKILL_FILE"; then
    echo "FAIL: doc-architect SKILL.md missing diff block example"
    exit 1
fi

# Test case 4: skill mentions diff mode notes section
if ! grep -q "Diff mode notes" "$SKILL_FILE"; then
    echo "FAIL: doc-architect SKILL.md missing 'Diff mode notes' section"
    exit 1
fi

echo "PASS: doc-architect skill includes --diff mode documentation"
