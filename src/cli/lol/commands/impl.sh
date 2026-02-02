#!/usr/bin/env bash
# lol impl command implementation
# Delegates to the Python workflow implementation

# Main _lol_cmd_impl function
# Arguments:
#   $1 - issue_no: Issue number to implement
#   $2 - backend: Backend in provider:model form (default: codex:gpt-5.2-codex)
#   $3 - max_iterations: Maximum acw iterations (default: 10)
#   $4 - yolo: Boolean flag for --yolo passthrough (0 or 1)
_lol_cmd_impl() {
    local issue_no="$1"
    local backend="${2:-codex:gpt-5.2-codex}"
    local max_iterations="${3:-10}"
    local yolo="${4:-0}"

    local yolo_flag=""
    if [ "$yolo" = "1" ]; then
        yolo_flag="--yolo"
    fi

    python -m agentize.cli impl \
        "$issue_no" \
        --backend "$backend" \
        --max-iterations "$max_iterations" \
        $yolo_flag
}
