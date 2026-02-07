#!/usr/bin/env bash
# lol impl command implementation
# Delegates to the Python workflow implementation

# Main _lol_cmd_impl function
# Arguments:
#   $1 - issue_no: Issue number to implement
#   $2 - backend: Backend in provider:model form (default: codex:gpt-5.2-codex)
#   $3 - max_iterations: Maximum acw iterations (default: 10)
#   $4 - yolo: Boolean flag for --yolo passthrough (0 or 1)
#   $5 - wait_for_ci: Boolean flag for --wait-for-ci (0 or 1)
_lol_cmd_impl() {
    local issue_no="$1"
    local backend="${2:-codex:gpt-5.2-codex}"
    local max_iterations="${3:-10}"
    local yolo="${4:-0}"
    local wait_for_ci="${5:-0}"

    # Preflight worktree: ensure worktree exists and navigate before workflow
    if type wt >/dev/null 2>&1; then
        if ! wt pathto "$issue_no" >/dev/null 2>&1; then
            wt spawn "$issue_no" --no-agent || return 1
        fi
        wt goto "$issue_no" >/dev/null 2>&1 || cd "$(wt pathto "$issue_no")" || return 1
    fi

    local yolo_flag=""
    if [ "$yolo" = "1" ]; then
        yolo_flag="--yolo"
    fi

    local wait_for_ci_flag=""
    if [ "$wait_for_ci" = "1" ]; then
        wait_for_ci_flag="--wait-for-ci"
    fi

    python -m agentize.cli impl \
        "$issue_no" \
        --backend "$backend" \
        --max-iterations "$max_iterations" \
        $yolo_flag \
        $wait_for_ci_flag
}
