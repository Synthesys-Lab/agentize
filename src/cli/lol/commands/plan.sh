#!/usr/bin/env bash
# lol plan command implementation
# Delegates to planner pipeline for multi-agent debate

# Run the multi-agent debate pipeline
# Usage: lol_cmd_plan <feature_desc_or_refine_instructions> <issue_mode> <verbose> <refine_issue_number>
lol_cmd_plan() {
    local feature_desc="$1"
    local issue_mode="$2"
    local verbose="$3"
    local refine_issue_number="$4"

    # Validate feature description
    if [ -z "$feature_desc" ] && [ -z "$refine_issue_number" ]; then
        echo "Error: Feature description is required." >&2
        echo "" >&2
        echo "Usage: lol plan [--dry-run] [--verbose] [--editor] [--refine <issue-number> [refinement-instructions]] [<feature-description>]" >&2
        return 1
    fi

    # Lazily load planner module if not already loaded
    if ! type "_planner_run_pipeline" >/dev/null 2>&1; then
        local planner_sh="$AGENTIZE_HOME/src/cli/planner.sh"
        if [ ! -f "$planner_sh" ]; then
            echo "Error: Planner module not found at $planner_sh" >&2
            return 1
        fi
        source "$planner_sh"
    fi

    # Delegate to planner pipeline
    _planner_run_pipeline "$feature_desc" "$issue_mode" "$verbose" "$refine_issue_number"
}
