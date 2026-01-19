#!/usr/bin/env bash
#
# Unified External Agent Invocation Wrapper
#
# This script provides a single source of truth for external agent invocation,
# supporting three-tier fallback: Codex -> Agent CLI -> Claude.
#
# Usage:
#   ./invoke-external-agent.sh <model> <input_file> <output_file>
#
# Arguments:
#   model        Model version to use (e.g., opus, gpt-5.2-codex). Passed to the agent.
#   input_file   Path to input prompt file
#   output_file  Path to output response file
#
# Environment:
#   AGENTIZE_EXTERNAL_AGENT  Agent selection (auto/codex/agent/claude). Default: auto
#                            auto = three-tier fallback: codex -> agent -> claude
#
# Exit codes:
#   0  Success
#   1  Agent unavailable or invalid configuration
#   2  Input file missing or invalid arguments

set -euo pipefail

# Parse arguments
MODEL="${1:-}"
INPUT_FILE="${2:-}"
OUTPUT_FILE="${3:-}"

# Validate arguments
if [ -z "$MODEL" ] || [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Usage: invoke-external-agent.sh <model> <input_file> <output_file>" >&2
    exit 2
fi

# Validate input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE" >&2
    exit 2
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Read agent selection from environment, default to auto
EXTERNAL_AGENT="${AGENTIZE_EXTERNAL_AGENT:-auto}"

# Validate agent selection
case "$EXTERNAL_AGENT" in
    auto|codex|agent|claude) ;;
    *) echo "Error: Invalid AGENTIZE_EXTERNAL_AGENT: $EXTERNAL_AGENT" >&2; exit 1 ;;
esac

# Helper: Check if CLI is available
cli_available() {
    command -v "$1" &>/dev/null
}

# Helper: Invoke specific agent with model
invoke_agent() {
    local agent_name="$1"
    local model="$2"
    case "$agent_name" in
        codex)
            echo "Using Codex CLI (model: ${model})..." >&2
            codex exec \
                -m "$model" \
                -s read-only \
                --enable web_search_request \
                -c model_reasoning_effort=xhigh \
                -o "$OUTPUT_FILE" \
                - < "$INPUT_FILE" >&2
            ;;
        agent)
            echo "Using Agent CLI (model: ${model})..." >&2
            cat "$INPUT_FILE" | agent -p -m "$model" > "$OUTPUT_FILE" 2>&1
            ;;
        claude)
            echo "Using Claude (model: ${model})..." >&2
            claude -p \
                --model "$model" \
                --tools "Read,Grep,Glob,WebSearch,WebFetch" \
                --permission-mode bypassPermissions \
                < "$INPUT_FILE" > "$OUTPUT_FILE" 2>&1
            ;;
    esac
}

# Route based on AGENTIZE_EXTERNAL_AGENT
case "$EXTERNAL_AGENT" in
    codex)
        cli_available codex || { echo "Error: AGENTIZE_EXTERNAL_AGENT=codex but codex CLI not found" >&2; exit 1; }
        invoke_agent codex "$MODEL"
        ;;
    agent)
        cli_available agent || { echo "Error: AGENTIZE_EXTERNAL_AGENT=agent but agent CLI not found" >&2; exit 1; }
        invoke_agent agent "$MODEL"
        ;;
    claude)
        cli_available claude || { echo "Error: AGENTIZE_EXTERNAL_AGENT=claude but claude CLI not found" >&2; exit 1; }
        invoke_agent claude "$MODEL"
        ;;
    auto)
        # Three-tier fallback: codex -> agent -> claude
        if cli_available codex; then
            invoke_agent codex "$MODEL"
        elif cli_available agent; then
            invoke_agent agent "$MODEL"
        elif cli_available claude; then
            invoke_agent claude "$MODEL"
        else
            echo "Error: No external agent available (tried codex, agent, claude)" >&2
            exit 1
        fi
        ;;
esac

# Verify output was created
if [ ! -f "$OUTPUT_FILE" ] || [ ! -s "$OUTPUT_FILE" ]; then
    echo "Error: Agent produced no output" >&2
    exit 1
fi

echo "Agent invocation completed successfully" >&2
exit 0
