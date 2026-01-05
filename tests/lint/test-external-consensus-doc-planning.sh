#!/bin/bash
set -e

# Test: external-consensus prompt includes Documentation Planning section

echo "Testing external-consensus prompt for Documentation Planning section..."

PROMPT_FILE=".claude/skills/external-consensus/external-review-prompt.md"

# Test case 1: prompt includes "Documentation Planning" heading
if ! grep -q "Documentation Planning" "$PROMPT_FILE"; then
    echo "FAIL: external-review-prompt.md missing 'Documentation Planning' section"
    exit 1
fi

# Test case 2: prompt mentions docs/ category
if ! grep -q "docs/" "$PROMPT_FILE"; then
    echo "FAIL: external-review-prompt.md missing 'docs/' reference"
    exit 1
fi

# Test case 3: prompt mentions README.md category
if ! grep -q "README.md" "$PROMPT_FILE"; then
    echo "FAIL: external-review-prompt.md missing 'README.md' reference"
    exit 1
fi

echo "PASS: external-consensus prompt includes Documentation Planning requirements"
