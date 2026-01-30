#!/usr/bin/env bash

# _lol_cmd_project: GitHub Projects v2 integration
# Runs in subshell to preserve set -e semantics
# Uses shared project library from src/cli/lol/project-lib.sh
# Usage: _lol_cmd_project <mode> [arg1] [arg2]
#   For create mode:    _lol_cmd_project create [org] [title]
#   For associate mode: _lol_cmd_project associate <org/id>
#   For automation mode: _lol_cmd_project automation [write_path]
_lol_cmd_project() (
    set -e

    # Positional arguments:
    #   $1 - mode: Operation mode - create, associate, automation (required)
    #   For create mode:
    #     $2 - org: Organization (optional, defaults to repo owner)
    #     $3 - title: Project title (optional, defaults to repo name)
    #   For associate mode:
    #     $2 - associate_arg: org/id argument (required, e.g., "Synthesys-Lab/3")
    #   For automation mode:
    #     $2 - write_path: Output path for workflow file (optional)

    local mode="$1"
    local arg1="$2"
    local arg2="$3"

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: mode is required (argument 1)"
        echo "Usage: _lol_cmd_project <mode> [arg1] [arg2]"
        exit 1
    fi

    # Source the shared project library
    source "$AGENTIZE_HOME/src/cli/lol/project-lib.sh"

    # Initialize project context (sets PROJECT_ROOT and METADATA_FILE)
    project_init_context || exit 1

    # Main execution
    case "$mode" in
        create)
            project_preflight_check || exit 1
            project_create "$arg1" "$arg2"
            echo ""
            echo "Next steps:"
            echo "  1. Set up automation: lol project --automation"
            ;;
        associate)
            project_preflight_check || exit 1
            project_associate "$arg1"
            echo ""
            echo "Next steps:"
            echo "  1. Set up automation: lol project --automation"
            ;;
        automation)
            project_generate_automation "$arg1"
            ;;
        *)
            echo "Error: Invalid mode '$mode'"
            exit 1
            ;;
    esac
)
