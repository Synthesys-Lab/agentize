#!/usr/bin/env bash
# Unified external agent invocation wrapper
# Usage: invoke-external-agent.sh <model> <input_file> <output_file>
#
# Reads AGENTIZE_EXTERNAL_AGENT to select agent:
#   auto   = Try codex, then agent, then claude (default)
#   codex  = Force codex (error if unavailable)
#   agent  = Force agent CLI (error if unavailable)
#   claude = Force claude (error if unavailable)

set -euo pipefail

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

# Read agent selection from environment
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

# Helper: Invoke specific agent
invoke_agent() {
    local agent_name="$1"
    case "$agent_name" in
        codex)
            codex exec -m gpt-5.2-codex -s read-only \
                -o "$OUTPUT_FILE" - < "$INPUT_FILE"
            ;;
        agent)
            cat "$INPUT_FILE" | agent -p > "$OUTPUT_FILE" 2>&1
            ;;
        claude)
            claude -p --model opus \
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
        invoke_agent codex
        ;;
    agent)
        cli_available agent || { echo "Error: AGENTIZE_EXTERNAL_AGENT=agent but agent CLI not found" >&2; exit 1; }
        invoke_agent agent
        ;;
    claude)
        cli_available claude || { echo "Error: AGENTIZE_EXTERNAL_AGENT=claude but claude CLI not found" >&2; exit 1; }
        invoke_agent claude
        ;;
    auto)
        # Three-tier fallback: codex → agent → claude
        if cli_available codex; then
            invoke_agent codex
        elif cli_available agent; then
            invoke_agent agent
        else
            invoke_agent claude
        fi
        ;;
esac
