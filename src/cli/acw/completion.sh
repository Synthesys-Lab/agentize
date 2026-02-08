#!/usr/bin/env bash
# acw CLI completion helper
# Returns newline-delimited lists for shell completion systems

# Usage: _acw_complete <topic>
# Topics: providers, cli-options
_acw_complete() {
    local topic="$1"

    case "$topic" in
        providers)
            echo "claude"
            echo "codex"
            echo "opencode"
            echo "cursor"
            echo "kimi"
            echo "gemini"
            ;;
        cli-options)
            echo "--help"
            echo "--chat"
            echo "--chat-list"
            echo "--editor"
            echo "--stdout"
            echo "--model"
            echo "--max-tokens"
            echo "--yolo"
            ;;
        *)
            # Unknown topic, return empty (graceful degradation)
            return 0
            ;;
    esac
}
