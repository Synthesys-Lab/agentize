#!/usr/bin/env bash
# acw helper functions (private)
# Validation and utility functions for the Agent CLI Wrapper
# All functions prefixed with _acw_ to prevent tab-completion pollution

# Validate required arguments
# Usage: _acw_validate_args <cli> <model> <input> <output>
# Returns: 0 if valid, 1 if missing args
_acw_validate_args() {
    local cli="$1"
    local model="$2"
    local input="$3"
    local output="$4"

    if [ -z "$cli" ]; then
        echo "Error: Missing cli-name argument" >&2
        return 1
    fi

    if [ -z "$model" ]; then
        echo "Error: Missing model-name argument" >&2
        return 1
    fi

    if [ -z "$input" ]; then
        echo "Error: Missing input-file argument" >&2
        return 1
    fi

    if [ -z "$output" ]; then
        echo "Error: Missing output-file argument" >&2
        return 1
    fi

    return 0
}

# Check if provider CLI binary exists
# Usage: _acw_check_cli <cli-name>
# Returns: 0 if exists, 4 if not found
_acw_check_cli() {
    local cli_name="$1"
    local binary=""

    case "$cli_name" in
        claude)
            binary="claude"
            ;;
        codex)
            binary="codex"
            ;;
        opencode)
            binary="opencode"
            ;;
        cursor)
            binary="agent"
            ;;
        kimi)
            binary="kimi"
            ;;
        gemini)
            binary="gemini"
            ;;
        *)
            echo "Error: Unknown provider '$cli_name'" >&2
            return 2
            ;;
    esac

    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "Error: CLI binary '$binary' not found in PATH" >&2
        return 4
    fi

    return 0
}

# Ensure output directory exists
# Usage: _acw_ensure_output_dir <output-file>
# Returns: 0 on success, non-zero on failure
_acw_ensure_output_dir() {
    local output="$1"
    local dir

    dir=$(dirname "$output")

    if [ -n "$dir" ] && [ "$dir" != "." ]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            echo "Error: Cannot create output directory '$dir'" >&2
            return 1
        fi
    fi

    return 0
}

# Check if input file exists and is readable
# Usage: _acw_check_input_file <input-file>
# Returns: 0 if exists and readable, 3 otherwise
_acw_check_input_file() {
    local input="$1"

    if [ ! -f "$input" ]; then
        echo "Error: Input file '$input' not found" >&2
        return 3
    fi

    if [ ! -r "$input" ]; then
        echo "Error: Input file '$input' is not readable" >&2
        return 3
    fi

    return 0
}

# ============================================================
# Chat session helpers
# ============================================================

# Returns the session directory path and ensures it exists
# Usage: dir=$(_acw_chat_session_dir)
_acw_chat_session_dir() {
    local dir="${AGENTIZE_HOME:-.}/.tmp/acw-sessions"
    mkdir -p "$dir"
    echo "$dir"
}

# Resolves a session ID to its file path
# Usage: path=$(_acw_chat_session_path "abc12345")
_acw_chat_session_path() {
    local session_id="$1"
    local dir
    dir=$(_acw_chat_session_dir)
    echo "$dir/${session_id}.md"
}

# Generates an 8-character base62 session ID
# Uses /dev/urandom for randomness, retries on collision
# Usage: id=$(_acw_chat_generate_session_id)
_acw_chat_generate_session_id() {
    local charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local id=""
    local session_dir=""
    local attempts=0
    local max_attempts=10
    local byte=""
    local idx=0
    local char=""

    session_dir=$(_acw_chat_session_dir)

    while [ $attempts -lt $max_attempts ]; do
        id=""
        # Generate 8 random characters from charset
        while [ ${#id} -lt 8 ]; do
            byte=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
            idx=$((byte % 62))
            # Use printf with cut for shell-neutral substring extraction
            char=$(printf '%s' "$charset" | cut -c$((idx + 1)))
            id="${id}${char}"
        done

        # Check for collision
        if [ ! -f "$session_dir/${id}.md" ]; then
            echo "$id"
            return 0
        fi

        attempts=$((attempts + 1))
    done

    echo "Error: Failed to generate unique session ID after $max_attempts attempts" >&2
    return 1
}

# Validates a session ID format (base62, length 8-12)
# Usage: _acw_chat_validate_session_id "abc12345"
# Returns: 0 if valid, 1 if invalid
_acw_chat_validate_session_id() {
    local id="$1"
    local len=${#id}

    # Check length (8-12 characters)
    if [ $len -lt 8 ] || [ $len -gt 12 ]; then
        return 1
    fi

    # Check base62 characters only (a-z, A-Z, 0-9)
    if ! echo "$id" | grep -qE '^[a-zA-Z0-9]+$'; then
        return 1
    fi

    return 0
}

# Creates a new session file with YAML front matter
# Usage: _acw_chat_create_session <path> <provider> <model>
_acw_chat_create_session() {
    local path="$1"
    local provider="$2"
    local model="$3"
    local created=""

    # Generate ISO-8601 UTC timestamp
    # Use explicit paths for zsh compatibility in heredocs
    created=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")

    /bin/cat > "$path" <<EOF
---
provider: $provider
model: $model
created: $created
---
EOF
}

# Validates a session file format
# Usage: _acw_chat_validate_session_file <path>
# Returns: 0 if valid, 5 if invalid
_acw_chat_validate_session_file() {
    local path="$1"
    local first_line=""

    # Check file exists
    if [ ! -f "$path" ]; then
        echo "Error: Session file not found: $path" >&2
        return 5
    fi

    # Check YAML front matter start
    # Use explicit path for zsh compatibility
    first_line=$(/usr/bin/sed -n '1p' "$path")
    if [ "$first_line" != "---" ]; then
        echo "Error: Session file missing YAML front matter" >&2
        return 5
    fi

    # Check required keys exist using explicit path for zsh compatibility
    if [ -z "$(/usr/bin/grep "^provider: " "$path")" ]; then
        echo "Error: Session file missing provider" >&2
        return 5
    fi

    if [ -z "$(/usr/bin/grep "^model: " "$path")" ]; then
        echo "Error: Session file missing model" >&2
        return 5
    fi

    if [ -z "$(/usr/bin/grep "^created: " "$path")" ]; then
        echo "Error: Session file missing created timestamp" >&2
        return 5
    fi

    return 0
}

# Prepares combined input for provider (session history + new user input)
# Usage: _acw_chat_prepare_input <session-file> <input-file> <combined-out>
_acw_chat_prepare_input() {
    local session_file="$1"
    local input_file="$2"
    local combined_out="$3"

    # Copy session file to combined output
    # Use explicit paths for zsh compatibility
    /bin/cp "$session_file" "$combined_out"

    # Check if session already has turns (contains "# User")
    if /usr/bin/grep -q "^# User" "$session_file"; then
        # Add separator
        echo "" >> "$combined_out"
        echo "---" >> "$combined_out"
    fi

    # Append new user input with header
    echo "" >> "$combined_out"
    echo "# User" >> "$combined_out"
    /bin/cat "$input_file" >> "$combined_out"
}

# Appends a turn (user input + assistant response) to session file
# Usage: _acw_chat_append_turn <session-file> <user-file> <assistant-file>
_acw_chat_append_turn() {
    local session_file="$1"
    local user_file="$2"
    local assistant_file="$3"

    # Check if session already has turns
    # Use explicit paths for zsh compatibility
    if /usr/bin/grep -q "^# User" "$session_file"; then
        # Add separator
        echo "" >> "$session_file"
        echo "---" >> "$session_file"
    fi

    # Append user turn
    echo "" >> "$session_file"
    echo "# User" >> "$session_file"
    /bin/cat "$user_file" >> "$session_file"

    # Append assistant turn
    echo "" >> "$session_file"
    echo "# Assistant" >> "$session_file"
    /bin/cat "$assistant_file" >> "$session_file"

    # Ensure trailing newline
    echo "" >> "$session_file"
}

# Lists all sessions with metadata
# Usage: _acw_chat_list_sessions
_acw_chat_list_sessions() {
    local session_dir=""
    local id=""
    local provider=""
    local model=""
    local created=""

    session_dir=$(_acw_chat_session_dir)

    # Check if any sessions exist
    if ! /bin/ls "$session_dir"/*.md >/dev/null 2>&1; then
        return 0
    fi

    # Print header
    printf "%-12s %-10s %-25s %s\n" "ID" "PROVIDER" "MODEL" "CREATED"
    printf "%-12s %-10s %-25s %s\n" "----" "--------" "-----" "-------"

    # List each session
    # Use explicit paths for zsh compatibility
    for session_file in "$session_dir"/*.md; do
        id=$(/usr/bin/basename "$session_file" .md)
        provider=$(/usr/bin/grep "^provider: " "$session_file" 2>/dev/null | /usr/bin/cut -d' ' -f2-)
        model=$(/usr/bin/grep "^model: " "$session_file" 2>/dev/null | /usr/bin/cut -d' ' -f2-)
        created=$(/usr/bin/grep "^created: " "$session_file" 2>/dev/null | /usr/bin/cut -d' ' -f2-)

        printf "%-12s %-10s %-25s %s\n" "$id" "$provider" "$model" "$created"
    done
}
