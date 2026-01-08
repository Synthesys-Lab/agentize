#!/bin/bash
set -e

source "$(dirname "$0")/../common.sh"

# Test: issue-to-impl command includes docs commit documentation

test_info "Testing issue-to-impl command for docs commit support"

COMMAND_FILE="$PROJECT_ROOT/.claude/commands/issue-to-impl.md"

# Test case 1: command Step 5 mentions documentation commit
if ! grep -q "Create documentation commit" "$COMMAND_FILE"; then
    test_fail "issue-to-impl.md missing 'Create documentation commit' in Step 5"
fi

# Test case 2: command mentions [docs] tag
if ! grep -q '\[docs\]' "$COMMAND_FILE"; then
    test_fail "issue-to-impl.md missing '[docs]' tag reference"
fi

# Test case 3a: command mentions commit-msg skill
if ! grep -q "commit-msg.*skill" "$COMMAND_FILE"; then
    test_fail "issue-to-impl.md missing commit-msg skill invocation for docs"
fi

# Test case 3b: command specifies delivery purpose
if ! grep -q "Purpose:.*delivery" "$COMMAND_FILE"; then
    test_fail "issue-to-impl.md missing delivery purpose specification"
fi

# Test case 4: workflow docs mention docs commit
WORKFLOW_FILE="$PROJECT_ROOT/docs/workflows/issue-to-impl.md"
if ! grep -q "Documentation Commit Convention" "$WORKFLOW_FILE"; then
    test_fail "issue-to-impl workflow docs missing 'Documentation Commit Convention' section"
fi

test_pass "issue-to-impl includes docs commit documentation"
