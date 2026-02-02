#!/usr/bin/env bash
# planner pipeline adapter
# Delegates multi-agent pipeline execution to the Python backend

# Run the full multi-agent debate pipeline
# Usage: _planner_run_pipeline "<feature-description>" [issue-mode] [verbose] [refine-issue-number]
_planner_run_pipeline() {
    local feature_desc="$1"
    local issue_mode="${2:-true}"
    local verbose="${3:-false}"
    local refine_issue_number="${4:-}"

    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
        echo "Error: Could not determine repo root. Set AGENTIZE_HOME or run inside a git repo." >&2
        return 1
    fi

    export AGENTIZE_HOME="$repo_root"
    if [ -n "${PYTHONPATH:-}" ]; then
        PYTHONPATH="$repo_root/python:${PYTHONPATH}"
    else
        PYTHONPATH="$repo_root/python"
    fi
    export PYTHONPATH

    local -a args
    args=(
        -m agentize.workflow.planner
        --feature-desc "$feature_desc"
        --issue-mode "$issue_mode"
        --verbose "$verbose"
    )

    if [ -n "$refine_issue_number" ]; then
        args+=(--refine-issue-number "$refine_issue_number")
    fi

    python "${args[@]}"
}
