#!/usr/bin/env bash
# Handsoff state utilities for session and state file management

# Get or generate session ID
# Returns session ID via stdout
handsoff_get_session_id() {
    # Prefer CLAUDE_SESSION_ID if set
    if [[ -n "$CLAUDE_SESSION_ID" ]]; then
        echo "$CLAUDE_SESSION_ID"
        return 0
    fi

    # Otherwise use/create session ID file
    local worktree_root
    worktree_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$worktree_root" ]]; then
        echo "generic-session" >&2
        return 1
    fi

    local session_dir="$worktree_root/.tmp/claude-hooks/handsoff-sessions"
    local session_id_file="$session_dir/current-session-id"

    mkdir -p "$session_dir"

    # Read existing or generate new
    if [[ -f "$session_id_file" ]]; then
        cat "$session_id_file"
    else
        local new_id="session-$(date +%s)-$$"
        echo "$new_id" > "$session_id_file"
        echo "$new_id"
    fi
}

# Read state file and populate variables
# Args: $1 = state file path
# Populates: WORKFLOW, STATE, COUNT, MAX
# Returns: 0 on success, 1 on invalid format
handsoff_read_state() {
    local state_file="$1"

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    local content
    content=$(cat "$state_file")

    # Parse colon-separated format: workflow:state:count:max
    IFS=: read -r WORKFLOW STATE COUNT MAX <<< "$content"

    # Validate all fields present
    if [[ -z "$WORKFLOW" || -z "$STATE" || -z "$COUNT" || -z "$MAX" ]]; then
        return 1
    fi

    # Validate numeric fields
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || ! [[ "$MAX" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    return 0
}

# Write state file atomically
# Args: $1 = state file path, $2 = workflow, $3 = state, $4 = count, $5 = max
# Returns: 0 on success, 1 on error
handsoff_write_state() {
    local state_file="$1"
    local workflow="$2"
    local state="$3"
    local count="$4"
    local max="$5"

    # Validate inputs
    if [[ -z "$workflow" || -z "$state" || -z "$count" || -z "$max" ]]; then
        return 1
    fi

    if ! [[ "$count" =~ ^[0-9]+$ ]] || ! [[ "$max" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Atomic write via temp file
    local temp_file="${state_file}.tmp"
    echo "${workflow}:${state}:${count}:${max}" > "$temp_file"
    mv "$temp_file" "$state_file"
}
