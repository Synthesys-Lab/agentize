#!/usr/bin/env bash
# planner CLI main dispatcher
# Entry point and help text

# Print usage information
_planner_usage() {
    cat <<'EOF'
planner: Multi-agent debate pipeline CLI

Runs the ultra-planner multi-agent debate pipeline using independent CLI
sessions with file-based I/O and parallel critique and reducer stages.

Usage:
  planner plan "<feature-description>"
  planner --help

Subcommands:
  plan          Run the full multi-agent debate pipeline for a feature

Options:
  --help        Show this help message

Pipeline Stages:
  1. Understander   (sonnet)  - Gather codebase context
  2. Bold-proposer  (opus)    - Research SOTA and propose solutions
  3. Critique       (opus)    - Validate assumptions (parallel)
  4. Reducer        (opus)    - Simplify proposal (parallel)
  5. Consensus      (external) - Synthesize final plan

Artifacts are written to .tmp/ with timestamp-based naming.

Examples:
  planner plan "Add user authentication with JWT tokens"
  planner plan "Refactor database layer for connection pooling"
EOF
}

# Main planner function
planner() {
    # Handle --help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        _planner_usage
        return 0
    fi

    # Show usage if no arguments
    if [ -z "$1" ]; then
        _planner_usage >&2
        return 1
    fi

    local subcommand="$1"
    shift

    case "$subcommand" in
        plan)
            # Validate feature description is provided
            if [ -z "$1" ]; then
                echo "Error: Feature description is required." >&2
                echo "" >&2
                echo "Usage: planner plan \"<feature-description>\"" >&2
                return 1
            fi

            local feature_desc="$1"
            _planner_run_pipeline "$feature_desc"
            ;;
        *)
            echo "Error: Unknown subcommand '$subcommand'" >&2
            echo "" >&2
            echo "Usage: planner plan \"<feature-description>\"" >&2
            echo "       planner --help" >&2
            return 1
            ;;
    esac
}
