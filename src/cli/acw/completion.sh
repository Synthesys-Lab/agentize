#!/usr/bin/env bash
# acw CLI completion helper
# Returns newline-delimited lists for shell completion systems

# Usage: acw_complete <topic>
# Topics: providers, cli-options
acw_complete() {
    local topic="$1"

    case "$topic" in
        providers)
            echo "claude"
            echo "codex"
            echo "opencode"
            echo "cursor"
            ;;
        cli-options)
            echo "--help"
            echo "--model"
            echo "--max-tokens"
            ;;
        *)
            # Unknown topic, return empty (graceful degradation)
            return 0
            ;;
    esac
}
