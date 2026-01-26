#!/usr/bin/env bash
#
# External Synthesize Script
#
# This script synthesizes implementation plan(s) from a 5-agent debate using external AI review.
# Can produce multiple options when no agreement exists.
#
# Usage:
#   ./external-synthesize.sh <bold> <paranoia> <critique> <proposal-reducer> <code-reducer> [consensus] [history]
#
# Arguments:
#   1-5: Required agent report files
#   6: Optional previous consensus file (for resolve/refine modes)
#   7: Optional history file (for resolve/refine modes)
#
# Context ordering rationale:
#   The combined report is assembled as: agent reports → previous consensus → history
#   This ensures the AI sees the history table's last row (current task) as the final context.
#
# Output:
#   Prints the path to the generated consensus plan file on stdout
#   Exit code 0 on success, non-zero on failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Validate input arguments
if [ $# -lt 5 ] || [ $# -gt 7 ]; then
    echo "Error: 5 to 7 arguments required" >&2
    echo "Usage: external-synthesize.sh <bold> <paranoia> <critique> <proposal-reducer> <code-reducer> [consensus] [history]" >&2
    exit 1
fi

BOLD_PATH="$1"
PARANOIA_PATH="$2"
CRITIQUE_PATH="$3"
PROPOSAL_REDUCER_PATH="$4"
CODE_REDUCER_PATH="$5"

# Optional consensus file (6th argument) and history file (7th argument)
CONSENSUS_PATH=""
HISTORY_PATH=""

if [ $# -ge 6 ]; then
    CONSENSUS_PATH="$6"
    if [ ! -f "$CONSENSUS_PATH" ]; then
        echo "Error: Consensus file not found: $CONSENSUS_PATH" >&2
        exit 1
    fi
    echo "Resolve/refine mode: Previous consensus file provided" >&2
fi

if [ $# -eq 7 ]; then
    HISTORY_PATH="$7"
    if [ ! -f "$HISTORY_PATH" ]; then
        echo "Error: History file not found: $HISTORY_PATH" >&2
        exit 1
    fi
    echo "Resolve/refine mode: History file provided" >&2
fi

# Validate all report files exist
for REPORT_PATH in "$BOLD_PATH" "$PARANOIA_PATH" "$CRITIQUE_PATH" "$PROPOSAL_REDUCER_PATH" "$CODE_REDUCER_PATH"; do
    if [ ! -f "$REPORT_PATH" ]; then
        echo "Error: Report file not found: $REPORT_PATH" >&2
        exit 1
    fi
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Extract issue number from first report filename
# Expected format: "issue-{N}-bold.md" or "issue-refine-{N}-bold.md" where N is the issue number
BOLD_BASENAME=$(basename "$BOLD_PATH")
ISSUE_NUMBER=""
ISSUE_PREFIX=""
# Pattern: starts with "issue-", optionally "refine-", then digits, then "-"
# BASH_REMATCH[1] captures the optional "refine-" prefix (Bash-specific feature)
# BASH_REMATCH[2] captures the issue number
if [[ "$BOLD_BASENAME" =~ ^issue-(refine-)?([0-9]+)- ]]; then
    ISSUE_NUMBER="${BASH_REMATCH[2]}"
    if [ -n "${BASH_REMATCH[1]}" ]; then
        ISSUE_PREFIX="issue-refine-${ISSUE_NUMBER}"
    else
        ISSUE_PREFIX="issue-${ISSUE_NUMBER}"
    fi
fi

# Extract feature name from report file
# Searches for lines matching markdown headers like:
#   "# Feature: X", "## Title: Y", "**Feature**: Z", "Feature - W"
# The grep pattern matches: optional "#" prefix, optional "**" bold markers,
# "Feature" or "Title" keyword, followed by ":" or "-" separator
extract_feature_name() {
    local report_path="$1"
    grep -iE "^(#+[[:space:]]*)?(\\*\\*)?(Feature|Title)(\\*\\*)?[[:space:]]*[:\-]" "$report_path" 2>/dev/null \
        | head -1 \
        | sed -E 's/^#+[[:space:]]*//; s/^\*\*(Feature|Title)\*\*[[:space:]]*[:\-][[:space:]]*//I; s/^(Feature|Title)[[:space:]]*[:\-][[:space:]]*//I' \
        || true
}

FEATURE_NAME="$(extract_feature_name "$BOLD_PATH")"
if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME="$(extract_feature_name "$PARANOIA_PATH")"
fi
if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME="Unknown Feature"
fi

FEATURE_DESCRIPTION="$FEATURE_NAME"

# Set file paths based on issue number
if [ -n "$ISSUE_PREFIX" ]; then
    INPUT_FILE=".tmp/${ISSUE_PREFIX}-partial-review-input.md"
    OUTPUT_FILE=".tmp/${ISSUE_PREFIX}-partial-review-output.txt"
    CONSENSUS_FILE=".tmp/${ISSUE_PREFIX}-consensus.md"
    DEBATE_FILE=".tmp/${ISSUE_PREFIX}-debate.md"
else
    INPUT_FILE=".tmp/partial-review-input-${TIMESTAMP}.md"
    OUTPUT_FILE=".tmp/partial-review-output-${TIMESTAMP}.txt"
    CONSENSUS_FILE=".tmp/consensus-plan-${TIMESTAMP}.md"
    DEBATE_FILE=".tmp/debate-report-${TIMESTAMP}.md"
fi

mkdir -p .tmp

# Load prompt template
PROMPT_TEMPLATE_PATH="${SKILL_DIR}/external-synthesize-prompt.md"
if [ ! -f "$PROMPT_TEMPLATE_PATH" ]; then
    echo "Error: Prompt template not found: $PROMPT_TEMPLATE_PATH" >&2
    exit 1
fi

# Combine all 5 reports into debate report
cat > "$DEBATE_FILE" <<EOF
# Multi-Agent Debate Report (Mega-Planner): $FEATURE_NAME

**Generated**: $(date +"%Y-%m-%d %H:%M")

This document combines five perspectives from the mega-planner dual-proposer debate system:
1. **Bold Proposer**: Innovative, SOTA-driven approach
2. **Paranoia Proposer**: Destructive refactoring approach
3. **Critique**: Feasibility analysis of both proposals
4. **Proposal Reducer**: Simplification of both proposals
5. **Code Reducer**: Code footprint analysis
6. **Previous Consensus Plan**: The plan being refined (if resolve/refine mode)
7. **Selection & Refine History**: History table with current task in last row (if resolve/refine mode)

---

## Part 1: Bold Proposer

$(cat "$BOLD_PATH")

---

## Part 2: Paranoia Proposer

$(cat "$PARANOIA_PATH")

---

## Part 3: Critique

$(cat "$CRITIQUE_PATH")

---

## Part 4: Proposal Reducer

$(cat "$PROPOSAL_REDUCER_PATH")

---

## Part 5: Code Reducer

$(cat "$CODE_REDUCER_PATH")

---
EOF

# If resolve/refine mode, append consensus as Part 6 (after all agent reports)
if [ -n "$CONSENSUS_PATH" ]; then
    cat >> "$DEBATE_FILE" <<EOF

## Part 6: Previous Consensus Plan

The following is the previous consensus plan being refined:

$(cat "$CONSENSUS_PATH")

---
EOF
    echo "Appended previous consensus to debate report" >&2
fi

# If resolve/refine mode, append history as Part 7 (after consensus)
if [ -n "$HISTORY_PATH" ]; then
    cat >> "$DEBATE_FILE" <<EOF

## Part 7: Selection & Refine History

**IMPORTANT**: The last row of the table below contains the current task requirement.
Apply the current task to the previous consensus plan to generate the updated plan.

$(cat "$HISTORY_PATH")

---
EOF
    echo "Appended history to debate report" >&2
fi

echo "Combined debate report saved to: $DEBATE_FILE" >&2

# Prepare input prompt
DEBATE_CONTENT=$(cat "$DEBATE_FILE")
TEMP_FILE=$(mktemp)
DEBATE_TEMP=$(mktemp)
trap "rm -f $TEMP_FILE $DEBATE_TEMP" EXIT

cat "$PROMPT_TEMPLATE_PATH" | \
    sed "s|{{FEATURE_NAME}}|$FEATURE_NAME|g" | \
    sed "s|{{FEATURE_DESCRIPTION}}|$FEATURE_DESCRIPTION|g" > "$TEMP_FILE"

echo "$DEBATE_CONTENT" > "$DEBATE_TEMP"
sed -e "/{{COMBINED_REPORT}}/r $DEBATE_TEMP" -e '/{{COMBINED_REPORT}}/d' "$TEMP_FILE" > "$INPUT_FILE"

if [ ! -f "$INPUT_FILE" ] || [ ! -s "$INPUT_FILE" ]; then
    echo "Error: Failed to create input prompt file" >&2
    exit 1
fi

echo "Using external AI reviewer for plan synthesis..." >&2
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

    codex exec \
        -m gpt-5.2-codex \
        -s read-only \
        --enable web_search_request \
        -c model_reasoning_effort=xhigh \
        -o "$OUTPUT_FILE" \
        - < "$INPUT_FILE" >&2

    EXIT_CODE=$?
else
    echo "Codex not available. Using Claude Opus..." >&2
    echo "- Model: opus (Claude Code CLI)" >&2
    echo "" >&2

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
    exit 1
fi

echo "" >&2
echo "External review completed!" >&2

# Copy output to consensus file
cat "$OUTPUT_FILE" > "$CONSENSUS_FILE"

echo "Consensus plan saved to: $CONSENSUS_FILE" >&2

# Check if disagreement sections were generated
if grep -qE "^## Disagreement [0-9]+:" "$CONSENSUS_FILE"; then
    echo "" >&2
    echo "NOTE: Disagreements identified - developer decision required" >&2
    DISAGREEMENT_COUNT=$(grep -cE "^## Disagreement [0-9]+:" "$CONSENSUS_FILE" 2>/dev/null || echo "0")
    echo "Disagreement points: $DISAGREEMENT_COUNT (each with 3 resolution options)" >&2
    echo "Review Agent Perspectives tables and select preferred options." >&2
else
    echo "" >&2
    echo "NOTE: Full consensus reached - no disagreements" >&2
    echo "Plan is ready for implementation." >&2
fi

echo "" >&2

# Output the consensus file path
echo "$CONSENSUS_FILE"

exit 0
