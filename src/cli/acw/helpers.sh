#!/usr/bin/env bash
# acw helper functions
# Validation and utility functions for the Agent CLI Wrapper

# Validate required arguments
# Usage: acw_validate_args <cli> <model> <input> <output>
# Returns: 0 if valid, 1 if missing args
acw_validate_args() {
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
# Usage: acw_check_cli <cli-name>
# Returns: 0 if exists, 4 if not found
acw_check_cli() {
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
# Usage: acw_ensure_output_dir <output-file>
# Returns: 0 on success, non-zero on failure
acw_ensure_output_dir() {
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
# Usage: acw_check_input_file <input-file>
# Returns: 0 if exists and readable, 3 otherwise
acw_check_input_file() {
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
