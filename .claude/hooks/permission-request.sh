#!/usr/bin/env bash

# Permission request hook for Claude Code
# Determines whether to allow, deny, or ask for permission based on CLAUDE_HANDSOFF

# Check if hands-off mode is enabled
is_hands_off_enabled() {
    # Check CLAUDE_HANDSOFF environment variable first
    if [[ -n "${CLAUDE_HANDSOFF}" ]]; then
        local value
        value=$(echo "${CLAUDE_HANDSOFF}" | tr '[:upper:]' '[:lower:]')

        # Strict allow-list: only these values enable hands-off
        if [[ "$value" == "true" || "$value" == "1" || "$value" == "yes" ]]; then
            return 0  # enabled
        else
            return 1  # disabled (fail-closed on invalid values)
        fi
    fi

    # Fallback to .claude/hands-off.json if env var is unset
    local json_file=".claude/hands-off.json"
    if [[ -f "$json_file" ]]; then
        local enabled
        enabled=$(grep -o '"enabled"[[:space:]]*:[[:space:]]*true' "$json_file")
        if [[ -n "$enabled" ]]; then
            return 0  # enabled via JSON
        fi
    fi

    return 1  # disabled by default
}

# Determine permission decision based on tool and operation
make_decision() {
    local tool="$1"
    local description="$2"
    local args="$3"

    # Check if hands-off mode is enabled
    if ! is_hands_off_enabled; then
        echo "ask"
        return
    fi

    # Hands-off mode is enabled, apply rules
    case "$tool" in
        "Read")
            # Safe read operations are auto-allowed in hands-off mode
            echo "allow"
            ;;
        "Bash")
            # Check for destructive commands
            if echo "$args" | grep -qE '(rm|delete|drop|truncate|format|mkfs|dd|>|>>|\||&)'; then
                echo "ask"  # Destructive operations always ask
            else
                echo "allow"
            fi
            ;;
        *)
            # Default: ask for other tools
            echo "ask"
            ;;
    esac
}

# Main entry point
main() {
    local tool="$1"
    local description="$2"
    local args="${3:-}"

    make_decision "$tool" "$description" "$args"
}

main "$@"
