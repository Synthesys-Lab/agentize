#!/usr/bin/env bash

# Permission request hook for Claude Code
# Determines whether to allow, deny, or ask for permission based on CLAUDE_HANDSOFF

# Check if hands-off mode is enabled
is_hands_off_enabled() {
    # Check CLAUDE_HANDSOFF environment variable
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

    return 1  # disabled by default (fail-closed)
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
        "Read"|"Edit"|"Write"|"Glob"|"Grep")
            # File operations are auto-allowed in hands-off mode
            echo "allow"
            ;;
        "Bash")
            # Extract command from args JSON if present
            local command=""
            if [[ -n "$args" ]]; then
                # Try to extract command field from JSON (portable sed approach)
                command=$(echo "$args" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                # If extraction failed, use args as-is
                if [[ -z "$command" ]]; then
                    command="$args"
                fi
            fi

            # Check for publish operations (must ask even in hands-off mode)
            if echo "$command" | grep -qE '^(git push|gh (pr|issue) create)'; then
                echo "ask"
                return
            fi

            # Check for destructive operations (deny or ask)
            if echo "$command" | grep -qE '(rm -rf|git clean|git reset --hard|git push --force)'; then
                echo "ask"
                return
            fi

            # Check for safe git commands
            if echo "$command" | grep -qE '^git (status|diff|log|show|rev-parse|checkout|switch|branch|add|commit|fetch|rebase)'; then
                echo "allow"
                return
            fi

            # Check for safe GitHub read operations
            if echo "$command" | grep -qE '^gh (issue view|pr view|pr list|issue list|search|run view|run list|pr diff|pr checks)'; then
                echo "allow"
                return
            fi

            # Check for test/build commands
            if echo "$command" | grep -qE '^(make (test|check|build|all|lint|setup)|npm test|pytest|ninja|cmake)'; then
                echo "allow"
                return
            fi

            # Check for test scripts in tests/ directory
            if echo "$command" | grep -qE '^(bash |sh |\./)tests/'; then
                echo "allow"
                return
            fi

            # Default for bash: ask
            echo "ask"
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
