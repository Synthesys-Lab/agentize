#!/bin/bash
set -e

# External Consensus Review Script
# Invokes Codex (preferred) or Claude Opus (fallback) to synthesize consensus from debate reports

# Usage: ./external-review.sh <combined-report-file> <feature-name> <feature-description>

if [ $# -lt 3 ]; then
    echo "Usage: $0 <combined-report-file> <feature-name> <feature-description>"
    echo ""
    echo "Example:"
    echo "  $0 .tmp/debate-report.md \"Auth System\" \"Add user authentication\""
    exit 1
fi

COMBINED_REPORT_FILE="$1"
FEATURE_NAME="$2"
FEATURE_DESCRIPTION="$3"

# Check if combined report exists
if [ ! -f "$COMBINED_REPORT_FILE" ]; then
    echo "Error: Combined report file not found: $COMBINED_REPORT_FILE"
    exit 1
fi

# Read the combined report
COMBINED_REPORT=$(cat "$COMBINED_REPORT_FILE")

# Load the prompt template
PROMPT_TEMPLATE=".tmp/templates/external-review-prompt.md"
if [ ! -f "$PROMPT_TEMPLATE" ]; then
    echo "Error: Prompt template not found: $PROMPT_TEMPLATE"
    exit 1
fi

# Generate the full prompt by substituting variables
PROMPT=$(cat "$PROMPT_TEMPLATE" | \
    sed "s|{{FEATURE_NAME}}|$FEATURE_NAME|g" | \
    sed "s|{{FEATURE_DESCRIPTION}}|$FEATURE_DESCRIPTION|g")

# Replace {{COMBINED_REPORT}} with actual report content
# Using a temporary file to handle multi-line replacement
TEMP_PROMPT=$(mktemp)
echo "$PROMPT" | awk -v report="$COMBINED_REPORT" '
    /{{COMBINED_REPORT}}/ { print report; next }
    { print }
' > "$TEMP_PROMPT"

# Try Codex first (if available)
if command -v codex &> /dev/null; then
    echo "Using Codex for external consensus review..."
    codex --model gpt-4 --prompt "$(cat "$TEMP_PROMPT")"
    RESULT=$?
    rm "$TEMP_PROMPT"
    exit $RESULT
fi

# Fallback to Claude CLI with Opus
if command -v claude &> /dev/null; then
    echo "Codex not available. Using Claude Opus as fallback..."
    # Create a temporary file with the prompt
    TEMP_INPUT=$(mktemp)
    cat "$TEMP_PROMPT" > "$TEMP_INPUT"

    # Invoke Claude CLI with Opus model
    claude --model opus < "$TEMP_INPUT"
    RESULT=$?

    rm "$TEMP_PROMPT"
    rm "$TEMP_INPUT"
    exit $RESULT
fi

# Neither tool available
rm "$TEMP_PROMPT"
echo "Error: Neither 'codex' nor 'claude' CLI tools are available."
echo ""
echo "Please install one of the following:"
echo "  - Codex CLI: https://github.com/openai/codex"
echo "  - Claude CLI: https://github.com/anthropics/claude-cli"
echo ""
echo "Or manually review the combined report and synthesize a consensus plan."
exit 1
