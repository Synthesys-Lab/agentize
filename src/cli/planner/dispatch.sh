#!/usr/bin/env bash
# planner CLI main dispatcher
# Entry point and help text

# Print usage information
_planner_usage() {
    cat <<'EOF'
planner: Multi-agent debate pipeline CLI

Runs the ultra-planner multi-agent debate pipeline using independent CLI
sessions with file-based I/O and parallel critique and reducer stages.

Note: The preferred entrypoint is `lol plan`. The `planner` command is
retained as a legacy alias.

Usage:
  planner plan [--dry-run] [--verbose] [--backend <provider:model>] \
    [--understander <provider:model>] [--bold <provider:model>] \
    [--critique <provider:model>] [--reducer <provider:model>] \
    "<feature-description>"
  planner --help

Subcommands:
  plan          Run the full multi-agent debate pipeline for a feature

Options:
  --dry-run     Skip GitHub issue creation; use timestamp-based artifacts
                (default creates a GitHub issue when gh is available)
  --verbose     Print detailed stage logs (quiet by default)
  --backend     Default backend for all stages (provider:model)
  --understander Override backend for understander stage
  --bold        Override backend for bold-proposer stage
  --critique    Override backend for critique stage
  --reducer     Override backend for reducer stage
  --help        Show this help message

Pipeline Stages:
  1. Understander   (sonnet)  - Gather codebase context
  2. Bold-proposer  (opus)    - Research SOTA and propose solutions
  3. Critique       (opus)    - Validate assumptions (parallel)
  4. Reducer        (opus)    - Simplify proposal (parallel)
  5. Consensus      (external) - Synthesize final plan

Artifacts are written to .tmp/ with issue-{N} naming (default) or
timestamp-based naming (with --dry-run).

Examples:
  planner plan "Add user authentication with JWT tokens"
  planner plan --dry-run "Refactor database layer for connection pooling"
  planner plan --verbose "Add real-time notifications"
  planner plan --understander cursor:gpt-5.2-codex "Plan with cursor understander"
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
            # Parse flags
            local issue_mode="true"
            local verbose="false"
            local backend_default=""
            local backend_understander=""
            local backend_bold=""
            local backend_critique=""
            local backend_reducer=""

            while [ $# -gt 0 ]; do
                case "$1" in
                    --dry-run)
                        issue_mode="false"
                        shift
                        ;;
                    --verbose)
                        verbose="true"
                        shift
                        ;;
                    --backend)
                        shift
                        if [ -z "$1" ]; then
                            echo "Error: --backend requires provider:model" >&2
                            echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                            return 1
                        fi
                        backend_default="$1"
                        shift
                        ;;
                    --understander)
                        shift
                        if [ -z "$1" ]; then
                            echo "Error: --understander requires provider:model" >&2
                            echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                            return 1
                        fi
                        backend_understander="$1"
                        shift
                        ;;
                    --bold)
                        shift
                        if [ -z "$1" ]; then
                            echo "Error: --bold requires provider:model" >&2
                            echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                            return 1
                        fi
                        backend_bold="$1"
                        shift
                        ;;
                    --critique)
                        shift
                        if [ -z "$1" ]; then
                            echo "Error: --critique requires provider:model" >&2
                            echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                            return 1
                        fi
                        backend_critique="$1"
                        shift
                        ;;
                    --reducer)
                        shift
                        if [ -z "$1" ]; then
                            echo "Error: --reducer requires provider:model" >&2
                            echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                            return 1
                        fi
                        backend_reducer="$1"
                        shift
                        ;;
                    -*)
                        echo "Error: Unknown option '$1'" >&2
                        echo "" >&2
                        echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                        return 1
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            # Validate feature description is provided
            if [ -z "$1" ]; then
                echo "Error: Feature description is required." >&2
                echo "" >&2
                echo "Usage: planner plan [options] \"<feature-description>\"" >&2
                return 1
            fi

            local feature_desc="$1"
            _planner_run_pipeline "$feature_desc" "$issue_mode" "$verbose" \
                "$backend_default" "$backend_understander" "$backend_bold" \
                "$backend_critique" "$backend_reducer"
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
