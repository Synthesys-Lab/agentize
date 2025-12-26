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
PROMPT_TEMPLATE="claude/skills/external-consensus/external-review-prompt.md"
if [ ! -f "$PROMPT_TEMPLATE" ]; then
    echo "Error: Prompt template not found: $PROMPT_TEMPLATE"
    echo "Expected location: $PROMPT_TEMPLATE (relative to project root)"
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

# Create timestamped temporary files for file-based I/O
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
INPUT_FILE=".tmp/external-review-input-$TIMESTAMP.md"
OUTPUT_FILE=".tmp/external-review-output-$TIMESTAMP.txt"

# Ensure .tmp directory exists
mkdir -p .tmp

# Write prompt to input file
cat "$TEMP_PROMPT" > "$INPUT_FILE"
rm "$TEMP_PROMPT"

# Try Codex first (if available)
if command -v codex &> /dev/null; then
    echo "Using Codex (gpt-5.2-codex) for external consensus review..." >&2

    # Invoke Codex with advanced features
    codex exec \
        -m gpt-5.2-codex \
        -s read-only \
        --enable web_search_request \
        -c model_reasoning_effort=xhigh \
        -i "$INPUT_FILE" \
        -o "$OUTPUT_FILE"

    RESULT=$?

    if [ $RESULT -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
        # Output consensus plan to stdout
        cat "$OUTPUT_FILE"

        # Clean up temp files
        rm "$INPUT_FILE" "$OUTPUT_FILE"
        exit 0
    else
        echo "Error: Codex execution failed (exit code: $RESULT)" >&2
        rm "$INPUT_FILE"
        [ -f "$OUTPUT_FILE" ] && rm "$OUTPUT_FILE"
        exit $RESULT
    fi
fi

# Fallback to Claude Code CLI with Opus (always available as part of this skill)
echo "Codex not available. Using Claude Opus as fallback..." >&2

# Invoke Claude Code with Opus model and read-only tools
claude -p \
    --model opus \
    --tools "Read,Grep,Glob,WebSearch,WebFetch" \
    --permission-mode bypassPermissions \
    < "$INPUT_FILE" > "$OUTPUT_FILE" 2>&1

RESULT=$?

if [ $RESULT -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    # Output consensus plan to stdout
    cat "$OUTPUT_FILE"

    # Clean up temp files
    rm "$INPUT_FILE" "$OUTPUT_FILE"
    exit 0
else
    echo "Error: Claude execution failed (exit code: $RESULT)" >&2
    rm "$INPUT_FILE"
    [ -f "$OUTPUT_FILE" ] && rm "$OUTPUT_FILE"
    exit $RESULT
fi
