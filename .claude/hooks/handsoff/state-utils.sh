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

# Check if debug logging is enabled
# Returns: 0 if enabled, 1 if disabled
handsoff_debug_enabled() {
    [[ "$HANDSOFF_DEBUG" == "true" ]]
}

# Escape string for JSON
# Args: $1 = string to escape
# Returns: escaped string via stdout
handsoff_json_escape() {
    local str="$1"
    # Escape backslashes first, then quotes, then newlines/tabs
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/\\r}"
    echo "$str"
}

# Log history entry to JSONL file
# Args: $1=event, $2=decision, $3=reason, $4=description, $5=tool_name, $6=tool_args, $7=new_state
# Uses global: SESSION_ID, WORKFLOW, STATE, COUNT, MAX
# Returns: 0 on success (best-effort, never fails)
handsoff_log_history() {
    # Skip if debug not enabled
    if ! handsoff_debug_enabled; then
        return 0
    fi

    local event="$1"
    local decision="$2"
    local reason="$3"
    local description="$4"
    local tool_name="$5"
    local tool_args="$6"
    local new_state="$7"

    # Get worktree root
    local worktree_root
    worktree_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0

    # Get session ID if not already set
    local session_id="${SESSION_ID:-}"
    if [[ -z "$session_id" ]]; then
        session_id=$(handsoff_get_session_id) || return 0
    fi

    # Prepare history directory
    local history_dir="$worktree_root/.tmp/claude-hooks/handsoff-sessions/history"
    mkdir -p "$history_dir" 2>/dev/null || return 0

    local history_file="$history_dir/${session_id}.jsonl"

    # Get timestamp in ISO 8601 format
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || timestamp=""

    # Escape all fields for JSON
    local esc_event=$(handsoff_json_escape "$event")
    local esc_workflow=$(handsoff_json_escape "${WORKFLOW:-}")
    local esc_state=$(handsoff_json_escape "${STATE:-}")
    local esc_count=$(handsoff_json_escape "${COUNT:-}")
    local esc_max=$(handsoff_json_escape "${MAX:-}")
    local esc_decision=$(handsoff_json_escape "$decision")
    local esc_reason=$(handsoff_json_escape "$reason")
    local esc_description=$(handsoff_json_escape "$description")
    local esc_tool_name=$(handsoff_json_escape "$tool_name")
    local esc_tool_args=$(handsoff_json_escape "$tool_args")
    local esc_new_state=$(handsoff_json_escape "$new_state")

    # Build JSON line (best-effort, ignore errors)
    {
        echo -n '{"timestamp":"'
        echo -n "$timestamp"
        echo -n '","session_id":"'
        echo -n "$session_id"
        echo -n '","event":"'
        echo -n "$esc_event"
        echo -n '","workflow":"'
        echo -n "$esc_workflow"
        echo -n '","state":"'
        echo -n "$esc_state"
        echo -n '","count":"'
        echo -n "$esc_count"
        echo -n '","max":"'
        echo -n "$esc_max"
        echo -n '","decision":"'
        echo -n "$esc_decision"
        echo -n '","reason":"'
        echo -n "$esc_reason"
        echo -n '","description":"'
        echo -n "$esc_description"
        echo -n '","tool_name":"'
        echo -n "$esc_tool_name"
        echo -n '","tool_args":"'
        echo -n "$esc_tool_args"
        echo -n '","new_state":"'
        echo -n "$esc_new_state"
        echo '"}'
    } >> "$history_file" 2>/dev/null || return 0

    # Always return success (best-effort logging)
    return 0
}
