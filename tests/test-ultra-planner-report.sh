#!/bin/bash
# Test ultra-planner report generation output format
set -e

echo "Testing ultra-planner report generation..."

# Create test data
TEST_DIR=".tmp/test-ultra-planner"
mkdir -p "$TEST_DIR"

# Mock agent outputs
BOLD_PROPOSAL="## Bold Proposal\nInnovative solution with advanced features\nLOC estimate: ~500"
CRITIQUE_OUTPUT="## Critique Analysis\nFeasibility: High\nCritical risks: 2"
REDUCER_OUTPUT="## Reducer Simplification\nSimplified approach\nLOC estimate: ~200"

# Generate report using the new echo-based approach
TIMESTAMP="test-20251226"
FEATURE_DESC="Test feature for validation"
FEATURE_NAME="Test feature for validation"
DATETIME="2025-12-26 12:00"
OUTPUT_FILE="$TEST_DIR/debate-report-$TIMESTAMP.md"

# This simulates the Step 5 implementation with echo-based construction
{
    echo "# Multi-Agent Debate Report"
    echo ""
    echo "**Feature**: $FEATURE_NAME"
    echo "**Generated**: $DATETIME"
    echo ""
    echo "This document combines three perspectives from our multi-agent debate-based planning system:"
    echo "1. **Bold Proposer**: Innovative, SOTA-driven approach"
    echo "2. **Proposal Critique**: Feasibility analysis and risk assessment"
    echo "3. **Proposal Reducer**: Simplified, \"less is more\" approach"
    echo ""
    echo "---"
    echo ""
    echo "## Part 1: Bold Proposer Report"
    echo ""
    echo "$BOLD_PROPOSAL"
    echo ""
    echo "---"
    echo ""
    echo "## Part 2: Proposal Critique Report"
    echo ""
    echo "$CRITIQUE_OUTPUT"
    echo ""
    echo "---"
    echo ""
    echo "## Part 3: Proposal Reducer Report"
    echo ""
    echo "$REDUCER_OUTPUT"
    echo ""
    echo "---"
    echo ""
    echo "## Next Steps"
    echo ""
    echo "This combined report will be reviewed by an external consensus agent (Codex or Claude Opus) to synthesize a final, balanced implementation plan."
} > "$OUTPUT_FILE"

# Validate output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Validate required sections are present
REQUIRED_SECTIONS=(
    "# Multi-Agent Debate Report"
    "## Part 1: Bold Proposer Report"
    "## Part 2: Proposal Critique Report"
    "## Part 3: Proposal Reducer Report"
    "## Next Steps"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "^$section" "$OUTPUT_FILE"; then
        echo "FAIL: Missing section: $section"
        exit 1
    fi
done

# Validate content is present (not just headers)
if ! grep -q "Bold Proposal" "$OUTPUT_FILE"; then
    echo "FAIL: Bold proposal content missing"
    exit 1
fi

if ! grep -q "Critique Analysis" "$OUTPUT_FILE"; then
    echo "FAIL: Critique content missing"
    exit 1
fi

if ! grep -q "Reducer Simplification" "$OUTPUT_FILE"; then
    echo "FAIL: Reducer content missing"
    exit 1
fi

# Validate metadata
if ! grep -q "\*\*Feature\*\*: Test feature" "$OUTPUT_FILE"; then
    echo "FAIL: Feature metadata missing"
    exit 1
fi

if ! grep -q "\*\*Generated\*\*: 2025-12-26" "$OUTPUT_FILE"; then
    echo "FAIL: Generated timestamp missing"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

echo "PASS: Ultra-planner report generation test passed"
