#!/usr/bin/env bash
# lol CLI argument parsers
# Parse command-line arguments and call command implementations

# Parse upgrade command arguments and call lol_cmd_upgrade
_lol_parse_upgrade() {
    # Reject unexpected arguments
    if [ $# -gt 0 ]; then
        echo "Error: lol upgrade does not accept arguments"
        echo "Usage: lol upgrade"
        return 1
    fi

    lol_cmd_upgrade
}

# Parse project command arguments and call lol_cmd_project
_lol_parse_project() {
    local mode=""
    local org=""
    local title=""
    local associate_arg=""
    local automation="0"
    local write_path=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --create)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --create with --associate or --automation"
                    echo "Usage: lol project --create [--org <owner>] [--title <title>]"
                    return 1
                fi
                mode="create"
                shift
                ;;
            --associate)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --associate with --create or --automation"
                    echo "Usage: lol project --associate <owner>/<id>"
                    return 1
                fi
                mode="associate"
                associate_arg="$2"
                shift 2
                ;;
            --automation)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --automation with --create or --associate"
                    echo "Usage: lol project --automation [--write <path>]"
                    return 1
                fi
                mode="automation"
                automation="1"
                shift
                ;;
            --org)
                org="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --write)
                write_path="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage:"
                echo "  lol project --create [--org <owner>] [--title <title>]"
                echo "  lol project --associate <owner>/<id>"
                echo "  lol project --automation [--write <path>]"
                return 1
                ;;
        esac
    done

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: Must specify --create, --associate, or --automation"
        echo "Usage:"
        echo "  lol project --create [--org <owner>] [--title <title>]"
        echo "  lol project --associate <owner>/<id>"
        echo "  lol project --automation [--write <path>]"
        return 1
    fi

    # Call command with positional arguments
    # For create: lol_cmd_project create [org] [title]
    # For associate: lol_cmd_project associate <org/id>
    # For automation: lol_cmd_project automation [write_path]
    case "$mode" in
        create)
            lol_cmd_project "create" "$org" "$title"
            ;;
        associate)
            lol_cmd_project "associate" "$associate_arg"
            ;;
        automation)
            lol_cmd_project "automation" "$write_path"
            ;;
    esac
}

# Parse serve command arguments and call lol_cmd_serve
# Note: lol serve no longer accepts CLI flags; configure .agentize.local.yaml instead
_lol_parse_serve() {
    # Reject any CLI arguments - configuration is YAML-only
    if [ $# -gt 0 ]; then
        echo "Error: lol serve no longer accepts CLI flags."
        echo ""
        echo "Configure server.period and server.num_workers in .agentize.local.yaml:"
        echo ""
        echo "  server:"
        echo "    period: 5m"
        echo "    num_workers: 5"
        return 1
    fi

    lol_cmd_serve
}

# Parse claude-clean command arguments and call lol_cmd_claude_clean
_lol_parse_claude_clean() {
    local dry_run="0"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run="1"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol claude-clean [--dry-run]"
                return 1
                ;;
        esac
    done

    lol_cmd_claude_clean "$dry_run"
}

# Parse usage command arguments and call lol_cmd_usage
_lol_parse_usage() {
    local mode="today"
    local cache="0"
    local cost="0"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --today)
                mode="today"
                shift
                ;;
            --week)
                mode="week"
                shift
                ;;
            --cache)
                cache="1"
                shift
                ;;
            --cost)
                cost="1"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol usage [--today | --week] [--cache] [--cost]"
                return 1
                ;;
        esac
    done

    lol_cmd_usage "$mode" "$cache" "$cost"
}

# Parse plan command arguments and call lol_cmd_plan
_lol_parse_plan() {
    local dry_run="false"
    local verbose="false"
    local feature_desc=""

    # Handle --help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "lol plan: Run the multi-agent debate pipeline"
        echo ""
        echo "Usage: lol plan [--dry-run] [--verbose] \"<feature-description>\""
        echo ""
        echo "Options:"
        echo "  --dry-run    Skip GitHub issue creation; use timestamp-based artifacts"
        echo "  --verbose    Print detailed stage logs (quiet by default)"
        echo "  --help       Show this help message"
        return 0
    fi

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --verbose)
                verbose="true"
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                echo "Usage: lol plan [--dry-run] [--verbose] \"<feature-description>\"" >&2
                return 1
                ;;
            *)
                if [ -z "$feature_desc" ]; then
                    feature_desc="$1"
                else
                    echo "Error: Unexpected argument '$1'" >&2
                    echo "Usage: lol plan [--dry-run] [--verbose] \"<feature-description>\"" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate feature description
    if [ -z "$feature_desc" ]; then
        echo "Error: Feature description is required." >&2
        echo "" >&2
        echo "Usage: lol plan [--dry-run] [--verbose] \"<feature-description>\"" >&2
        return 1
    fi

    # Convert --dry-run to issue_mode (inverse logic)
    local issue_mode="true"
    if [ "$dry_run" = "true" ]; then
        issue_mode="false"
    fi

    lol_cmd_plan "$feature_desc" "$issue_mode" "$verbose"
}
