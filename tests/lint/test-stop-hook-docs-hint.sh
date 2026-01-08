#!/bin/bash
set -e

# Test: stop.py includes documentation phase hint for issue-to-impl workflow

echo "Testing stop.py hook for documentation phase hint..."

HOOK_FILE=".claude/hooks/stop.py"

# Test case 1: stop.py mentions "Documentation Planning" section
if ! grep -q "Documentation Planning" "$HOOK_FILE"; then
    echo "FAIL: stop.py missing 'Documentation Planning' reference"
    exit 1
fi

# Test case 2: stop.py mentions [docs] commit
if ! grep -q '\[docs\] commit' "$HOOK_FILE"; then
    echo "FAIL: stop.py missing '[docs] commit' reference"
    exit 1
fi

# Test case 3: stop.py mentions diff specifications
if ! grep -q "diff" "$HOOK_FILE"; then
    echo "FAIL: stop.py missing 'diff' reference"
    exit 1
fi

echo "PASS: stop.py includes documentation phase hint"
