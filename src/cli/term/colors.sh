#!/usr/bin/env bash
# Shared terminal styling helpers for CLI output
# Provides consistent label formatting and cursor control

# Check if color output is enabled on stderr
# Returns 0 if color should be used, 1 otherwise
# Respects NO_COLOR (https://no-color.org/) and PLANNER_NO_COLOR
term_color_enabled() {
    [ -z "${NO_COLOR:-}" ] && [ -z "${PLANNER_NO_COLOR:-}" ] && [ -t 2 ]
}

# Print styled label and text to stderr
# Usage: term_label <label> <text> [style]
# Styles: info (cyan bold), success (green bold)
# Falls back to plain text if colors disabled or style unknown
term_label() {
    local label="$1"
    local text="$2"
    local style="${3:-}"

    if ! term_color_enabled; then
        echo "$label $text" >&2
        return
    fi

    local color_code=""
    case "$style" in
        info)    color_code='\033[1;36m' ;;  # cyan bold
        success) color_code='\033[1;32m' ;;  # green bold
        *)       echo "$label $text" >&2; return ;;
    esac

    printf '%b%s\033[0m %s\n' "$color_code" "$label" "$text" >&2
}

# Emit cursor clear sequence to stderr for animation
# Clears current line: carriage return + clear to end of line
term_clear_line() {
    printf '\r\033[K' >&2
}
