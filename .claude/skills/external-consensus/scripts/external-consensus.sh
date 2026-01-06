#!/usr/bin/env bash
#
# External Consensus Review Script
#
# This script synthesizes a consensus implementation plan from a multi-agent
# debate report using an external AI reviewer (Codex or Claude Opus).
#
# Usage:
#   ./external-consensus.sh <path-to-report1> <path-to-report2> <path-to-report3>
#
# Arguments:
#   path-to-report1   Path to first agent report (e.g., bold-proposer output) (required)
#   path-to-report2   Path to second agent report (e.g., critique output) (required)
#   path-to-report3   Path to third agent report (e.g., reducer output) (required)
#
# Output:
#   Prints the path to the generated consensus plan file on stdout
#   Exit code 0 on success, non-zero on failure
#
# Environment:
#   This script must be run from the repository root directory

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Validate input arguments
if [ $# -ne 3 ]; then
    echo "Error: Exactly 3 report paths are required" >&2
    echo "Usage: $0 <path-to-report1> <path-to-report2> <path-to-report3>" >&2
    exit 1
fi

# Accept 3 report paths
REPORT1_PATH="$1"
REPORT2_PATH="$2"
REPORT3_PATH="$3"

# Validate all report files exist
for REPORT_PATH in "$REPORT1_PATH" "$REPORT2_PATH" "$REPORT3_PATH"; do
    if [ ! -f "$REPORT_PATH" ]; then
        echo "Error: Report file not found: $REPORT_PATH" >&2
        exit 1
    fi
done

# Generate timestamp for temp files
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Extract issue number from first report filename
REPORT1_BASENAME=$(basename "$REPORT1_PATH")
ISSUE_NUMBER=""
if [[ "$REPORT1_BASENAME" =~ ^issue-([0-9]+)- ]]; then
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
fi

# Extract feature name from reports using robust pattern matching
# Accepts multiple formats: headers (# Feature:), bold labels (**Feature**:), plain labels (Feature:)
# Scans reports 1 → 2 → 3 in priority order until first match found
extract_feature_name() {
    local report_path="$1"
    # Match patterns (case-insensitive):
    # - Headers: # Feature: or ## Title:
    # - Bold labels: **Feature**: or **Title**:
    # - Plain labels: Feature: or Title:
    # - Variants: Feature Request, Title
    grep -iE "^(#+[[:space:]]*)?(\\*\\*)?(Feature( Request)?|Title)(\\*\\*)?[[:space:]]*[:\-]" "$report_path" 2>/dev/null \
        | head -1 \
        | sed -E 's/^#+[[:space:]]*//; s/^\*\*(Feature( Request)?|Title)\*\*[[:space:]]*[:\-][[:space:]]*//I; s/^(Feature( Request)?|Title)[[:space:]]*[:\-][[:space:]]*//I; s/^\[[^]]*\]:[[:space:]]*//' \
        || true
}

# Try to extract feature name from reports in priority order
FEATURE_NAME="$(extract_feature_name "$REPORT1_PATH")"
if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME="$(extract_feature_name "$REPORT2_PATH")"
fi
if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME="$(extract_feature_name "$REPORT3_PATH")"
fi
if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME="Unknown Feature"
fi

# Use feature name as description
FEATURE_DESCRIPTION="$FEATURE_NAME"

# Prepare input prompt file and consensus file with issue-based naming if available
if [ -n "$ISSUE_NUMBER" ]; then
    INPUT_FILE=".tmp/issue-${ISSUE_NUMBER}-external-review-input.md"
    OUTPUT_FILE=".tmp/issue-${ISSUE_NUMBER}-external-review-output.txt"
    CONSENSUS_FILE=".tmp/issue-${ISSUE_NUMBER}-consensus.md"
else
    # Fall back to timestamp-based naming for backward compatibility
    INPUT_FILE=".tmp/external-review-input-${TIMESTAMP}.md"
    OUTPUT_FILE=".tmp/external-review-output-${TIMESTAMP}.txt"
    CONSENSUS_FILE=".tmp/consensus-plan-${TIMESTAMP}.md"
fi

# Ensure .tmp directory exists
mkdir -p .tmp

# Load prompt template
PROMPT_TEMPLATE_PATH="${SKILL_DIR}/external-review-prompt.md"
if [ ! -f "$PROMPT_TEMPLATE_PATH" ]; then
    echo "Error: Prompt template not found: $PROMPT_TEMPLATE_PATH" >&2
    exit 1
fi

# Prepare debate report file path
if [ -n "$ISSUE_NUMBER" ]; then
    DEBATE_REPORT_FILE=".tmp/issue-${ISSUE_NUMBER}-debate.md"
else
    DEBATE_REPORT_FILE=".tmp/debate-report-${TIMESTAMP}.md"
fi

# Combine all 3 reports into a single debate report file
cat > "$DEBATE_REPORT_FILE" <<EOF
# Multi-Agent Debate Report: $FEATURE_NAME

**Generated**: $(date +"%Y-%m-%d %H:%M")

This document combines three perspectives from our multi-agent debate-based planning system:
1. **Report 1**: $(basename "$REPORT1_PATH")
2. **Report 2**: $(basename "$REPORT2_PATH")
3. **Report 3**: $(basename "$REPORT3_PATH")

---

## Part 1: $(basename "$REPORT1_PATH")

$(cat "$REPORT1_PATH")

---

## Part 2: $(basename "$REPORT2_PATH")

$(cat "$REPORT2_PATH")

---

## Part 3: $(basename "$REPORT3_PATH")

$(cat "$REPORT3_PATH")

---

## Next Steps

This combined report will be reviewed by an external consensus agent (Codex or Claude Opus) to synthesize a final, balanced implementation plan.
EOF

# Load the combined debate report content for use in external review
DEBATE_REPORT_CONTENT=$(cat "$DEBATE_REPORT_FILE")

echo "Combined debate report saved to: $DEBATE_REPORT_FILE" >&2
echo "" >&2

# Create temporary file for substitution
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Substitute FEATURE_NAME and FEATURE_DESCRIPTION in template
cat "$PROMPT_TEMPLATE_PATH" | \
    sed "s|{{FEATURE_NAME}}|$FEATURE_NAME|g" | \
    sed "s|{{FEATURE_DESCRIPTION}}|$FEATURE_DESCRIPTION|g" > "$TEMP_FILE"

# Create another temp file for the debate report
DEBATE_TEMP=$(mktemp)
trap "rm -f $TEMP_FILE $DEBATE_TEMP" EXIT
echo "$DEBATE_REPORT_CONTENT" > "$DEBATE_TEMP"

# Replace {{COMBINED_REPORT}} placeholder with actual content
sed -e "/{{COMBINED_REPORT}}/r $DEBATE_TEMP" -e '/{{COMBINED_REPORT}}/d' "$TEMP_FILE" > "$INPUT_FILE"

# Validate input prompt was created
if [ ! -f "$INPUT_FILE" ] || [ ! -s "$INPUT_FILE" ]; then
    echo "Error: Failed to create input prompt file" >&2
    exit 1
fi

echo "Using external AI reviewer for consensus synthesis..." >&2
echo "" >&2
echo "Configuration:" >&2
echo "- Input: $INPUT_FILE ($(wc -l < "$INPUT_FILE") lines)" >&2
echo "- Output: $OUTPUT_FILE" >&2
echo "" >&2

# Check if Codex is available
if command -v codex &> /dev/null; then
    echo "- Model: gpt-5.2-codex (Codex CLI)" >&2
    echo "- Sandbox: read-only" >&2
    echo "- Web search: enabled" >&2
    echo "- Reasoning effort: xhigh" >&2
    echo "" >&2
    echo "This will take 2-5 minutes with xhigh reasoning effort..." >&2
    echo "" >&2

    # Invoke Codex with advanced features
    codex exec \
        -m gpt-5.2-codex \
        -s read-only \
        --enable web_search_request \
        -c model_reasoning_effort=xhigh \
        -o "$OUTPUT_FILE" \
        - < "$INPUT_FILE" >&2

    EXIT_CODE=$?
else
    echo "Codex not available. Using Claude Opus as fallback..." >&2
    echo "- Model: opus (Claude Code CLI)" >&2
    echo "- Tools: Read, Grep, Glob, WebSearch, WebFetch (read-only)" >&2
    echo "- Permission mode: bypassPermissions" >&2
    echo "" >&2
    echo "This will take 1-3 minutes..." >&2
    echo "" >&2

    # Invoke Claude Code with Opus and read-only tools
    claude -p \
        --model opus \
        --tools "Read,Grep,Glob,WebSearch,WebFetch" \
        --permission-mode bypassPermissions \
        < "$INPUT_FILE" > "$OUTPUT_FILE" 2>&1

    EXIT_CODE=$?
fi

# Check if external review succeeded
if [ $EXIT_CODE -ne 0 ] || [ ! -f "$OUTPUT_FILE" ] || [ ! -s "$OUTPUT_FILE" ]; then
    echo "" >&2
    echo "Error: External review failed with exit code $EXIT_CODE" >&2
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Output file exists but may be empty or incomplete" >&2
    fi
    exit 1
fi

echo "" >&2
echo "External review completed successfully!" >&2

# Copy output to consensus plan file
cat "$OUTPUT_FILE" > "$CONSENSUS_FILE"

echo "Consensus plan saved to: $CONSENSUS_FILE ($(wc -l < "$CONSENSUS_FILE") lines)" >&2
echo "" >&2

# Validate consensus plan
echo "Validating consensus plan..." >&2
MISSING_SECTIONS=""

# Check for required sections (flexible pattern matching)
grep -qi "implementation plan" "$CONSENSUS_FILE" || MISSING_SECTIONS="$MISSING_SECTIONS Implementation-Plan,"
grep -qi "architecture" "$CONSENSUS_FILE" || MISSING_SECTIONS="$MISSING_SECTIONS Architecture,"
grep -qi "implementation steps" "$CONSENSUS_FILE" || MISSING_SECTIONS="$MISSING_SECTIONS Implementation-Steps,"

if [ -n "$MISSING_SECTIONS" ]; then
    echo "⚠️  Warning: Consensus plan may be incomplete. Missing sections: $MISSING_SECTIONS" >&2
else
    echo "✅ All required sections present" >&2
fi
echo "" >&2

# Extract summary information
echo "Consensus Plan Summary:" >&2
echo "- Feature: $FEATURE_NAME" >&2

# Extract total LOC estimate (look for "Total:" or similar patterns)
TOTAL_LOC=$(grep -i "total.*LOC" "$CONSENSUS_FILE" | head -1 | grep -o '\~[0-9][0-9]*[–-][0-9][0-9]*\|\~[0-9][0-9]*' | head -1)
if [ -z "$TOTAL_LOC" ]; then
    TOTAL_LOC="Not specified"
fi

# Extract complexity rating
COMPLEXITY=$(grep -i "total.*LOC" "$CONSENSUS_FILE" | head -1 | grep -o '([A-Za-z]*' | tr -d '(' | head -1)
if [ -z "$COMPLEXITY" ]; then
    COMPLEXITY="Unknown"
fi

echo "- Total LOC: $TOTAL_LOC ($COMPLEXITY)" >&2

# Count implementation steps (matches format: "- **Step 1:" or "**Step 1:")
STEP_COUNT=$(grep -Eci "Step [0-9]+:" "$CONSENSUS_FILE" 2>/dev/null | tr -d '\n' || echo "0")
if [ -z "$STEP_COUNT" ] || [ "$STEP_COUNT" -eq 0 ]; then
    STEP_COUNT="Multiple"
fi
echo "- Implementation Steps: $STEP_COUNT" >&2

# Count risks
RISK_COUNT=$(grep "^|" "$CONSENSUS_FILE" 2>/dev/null | grep -v "^| Risk" | grep -v "^|---" | wc -l | tr -d ' ')
if [ "$RISK_COUNT" -eq 0 ]; then
    RISK_COUNT="Not specified"
fi
echo "- Risks Identified: $RISK_COUNT" >&2

echo "" >&2

# Extract key decisions
echo "Key Decisions:" >&2
grep -i "bold propos" "$CONSENSUS_FILE" | head -3 | sed 's/^/- /' >&2 2>/dev/null || echo "- (See consensus plan for details)" >&2

echo "" >&2
echo "Next step: Review plan and create GitHub issue with open-issue skill." >&2
echo "" >&2

# Output the consensus file path to stdout for the skill to capture
echo "$CONSENSUS_FILE"

exit 0
