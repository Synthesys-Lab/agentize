#!/usr/bin/env bash
#
# Lint test for partial-review-prompt.md structure
#

set -euo pipefail

source "$(dirname "$0")/../common.sh"

PROMPT_FILE="$PROJECT_ROOT/.claude-plugin/skills/partial-consensus/partial-review-prompt.md"

echo "Testing partial-review-prompt.md structure..."

# Test 1: TOC section exists
if ! grep -q "## Table of Contents" "$PROMPT_FILE"; then
    echo "FAIL: Missing '## Table of Contents' section"
    exit 1
fi
echo "PASS: TOC section exists"

# Test 2: TOC contains core anchors
REQUIRED_ANCHORS=(
    "#agent-perspectives-summary"
    "#consensus-status"
    "#goal"
    "#implementation-steps"
)

for anchor in "${REQUIRED_ANCHORS[@]}"; do
    if ! grep -q "$anchor" "$PROMPT_FILE"; then
        echo "FAIL: Missing required TOC anchor: $anchor"
        exit 1
    fi
done
echo "PASS: Required TOC anchors present"

# Test 3: Resolution Options Summary table header exists
if ! grep -qE "\| Option \| Name \| Source \| Summary \|" "$PROMPT_FILE"; then
    echo "FAIL: Missing Resolution Options Summary table"
    exit 1
fi
echo "PASS: Resolution Options Summary table present"

echo "All partial-review-prompt.md structure tests passed!"
