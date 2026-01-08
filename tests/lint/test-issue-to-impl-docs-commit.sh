#!/bin/bash
set -e

# Test: issue-to-impl command includes docs commit documentation

echo "Testing issue-to-impl command for docs commit support..."

COMMAND_FILE=".claude/commands/issue-to-impl.md"

# Test case 1: command Step 5 mentions documentation commit
if ! grep -q "Create documentation commit" "$COMMAND_FILE"; then
    echo "FAIL: issue-to-impl.md missing 'Create documentation commit' in Step 5"
    exit 1
fi

# Test case 2: command mentions [docs] tag
if ! grep -q '\[docs\]' "$COMMAND_FILE"; then
    echo "FAIL: issue-to-impl.md missing '[docs]' tag reference"
    exit 1
fi

# Test case 3: command mentions commit-msg skill for docs
if ! grep -q "commit-msg.*skill" "$COMMAND_FILE" && grep -q "Purpose:.*delivery" "$COMMAND_FILE"; then
    echo "FAIL: issue-to-impl.md missing commit-msg skill invocation for docs"
    exit 1
fi

# Test case 4: workflow docs mention docs commit
WORKFLOW_FILE="docs/workflows/issue-to-impl.md"
if ! grep -q "Documentation Commit Convention" "$WORKFLOW_FILE"; then
    echo "FAIL: issue-to-impl workflow docs missing 'Documentation Commit Convention' section"
    exit 1
fi

echo "PASS: issue-to-impl includes docs commit documentation"
