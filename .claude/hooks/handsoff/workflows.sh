#!/usr/bin/env bash
# Handsoff workflow detection and state transitions

# Detect workflow from user prompt
# Args: $1 = prompt text
# Returns: workflow name via stdout, empty if no workflow detected
handsoff_detect_workflow() {
    local prompt="$1"

    # Check for ultra-planner
    if echo "$prompt" | grep -qE '/ultra-planner'; then
        echo "ultra-planner"
        return 0
    fi

    # Check for issue-to-impl
    if echo "$prompt" | grep -qE '/issue-to-impl'; then
        echo "issue-to-impl"
        return 0
    fi

    # No workflow detected
    echo ""
    return 1
}

# Check if workflow is done
# Args: $1 = workflow name, $2 = current state
# Returns: 0 if done, 1 if not done
handsoff_is_done() {
    local workflow="$1"
    local state="$2"

    if [[ "$state" == "done" ]]; then
        return 0
    fi

    return 1
}

# Compute next state based on workflow and tool usage
# Args: $1 = workflow, $2 = current state, $3 = tool name, $4 = tool args
# Returns: new state via stdout (same as current if no transition)
handsoff_transition() {
    local workflow="$1"
    local current_state="$2"
    local tool_name="$3"
    local tool_args="$4"

    # ultra-planner workflow transitions
    if [[ "$workflow" == "ultra-planner" ]]; then
        # planning -> awaiting_details (on open-issue --auto)
        if [[ "$current_state" == "planning" && "$tool_name" == "open-issue" ]]; then
            if echo "$tool_args" | grep -qE -- '--auto'; then
                echo "awaiting_details"
                return 0
            fi
        fi

        # awaiting_details -> done (on open-issue --update, meaning plan update)
        if [[ "$current_state" == "awaiting_details" && "$tool_name" == "open-issue" ]]; then
            # Check for --update flag specifically (not just any issue number)
            if echo "$tool_args" | grep -qE -- '--update'; then
                echo "done"
                return 0
            fi
        fi
    fi

    # issue-to-impl workflow transitions
    if [[ "$workflow" == "issue-to-impl" ]]; then
        # docs_tests -> implementation (on milestone skill)
        if [[ "$current_state" == "docs_tests" && "$tool_name" == "milestone" ]]; then
            echo "implementation"
            return 0
        fi

        # implementation -> done (on open-pr skill)
        if [[ "$current_state" == "implementation" && "$tool_name" == "open-pr" ]]; then
            echo "done"
            return 0
        fi
    fi

    # No transition, return current state
    echo "$current_state"
}

# Get initial state for workflow
# Args: $1 = workflow name
# Returns: initial state via stdout
handsoff_initial_state() {
    local workflow="$1"

    case "$workflow" in
        "ultra-planner")
            echo "planning"
            ;;
        "issue-to-impl")
            echo "docs_tests"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}
