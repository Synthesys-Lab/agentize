#!/bin/bash
set -e

source "$(dirname "$0")/../common.sh"

# Test: stop.py includes documentation phase hint for issue-to-impl workflow

test_info "Testing stop.py hook for documentation phase hint"

HOOK_FILE="$PROJECT_ROOT/.claude/hooks/stop.py"

# Test case 1: stop.py mentions "Documentation Planning" section
if ! grep -q "Documentation Planning" "$HOOK_FILE"; then
    test_fail "stop.py missing 'Documentation Planning' reference"
fi

# Test case 2: stop.py mentions [docs] commit
if ! grep -q '\[docs\] commit' "$HOOK_FILE"; then
    test_fail "stop.py missing '[docs] commit' reference"
fi

# Test case 3: stop.py mentions diff specifications
if ! grep -q "diff" "$HOOK_FILE"; then
    test_fail "stop.py missing 'diff' reference"
fi

test_pass "stop.py includes documentation phase hint"
