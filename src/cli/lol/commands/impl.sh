#!/usr/bin/env bash
# lol impl command implementation
# Delegates to the Python workflow implementation

# Main _lol_cmd_impl function
# Arguments:
#   $1 - issue_no: Issue number to implement
#   $2 - backend: Optional backend in provider:model form
#   $3 - max_iterations: Optional maximum implementation iterations
#   $4 - yolo: Boolean flag for --yolo passthrough (0 or 1)
#   $5 - wait_for_ci: Boolean flag for --wait-for-ci (0 or 1)
_lol_cmd_impl() {
    local issue_no="$1"
    local backend="${2:-}"
    local max_iterations="${3:-}"
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

    local -a cmd=(python -m agentize.cli impl "$issue_no")
    if [ -n "$backend" ]; then
        cmd+=(--backend "$backend")
    fi
    if [ -n "$max_iterations" ]; then
        cmd+=(--max-iterations "$max_iterations")
    fi
    if [ -n "$yolo_flag" ]; then
        cmd+=("$yolo_flag")
    fi
    if [ -n "$wait_for_ci_flag" ]; then
        cmd+=("$wait_for_ci_flag")
    fi

    "${cmd[@]}"
}
