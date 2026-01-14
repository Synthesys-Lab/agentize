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
_lol_parse_serve() {
    local period="5m"
    local tg_token=""
    local tg_chat_id=""
    local num_workers="5"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --period=*)
                period="${1#*=}"
                shift
                ;;
            --tg-token=*)
                tg_token="${1#*=}"
                shift
                ;;
            --tg-chat-id=*)
                tg_chat_id="${1#*=}"
                shift
                ;;
            --num-workers=*)
                num_workers="${1#*=}"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol serve --tg-token=<token> --tg-chat-id=<id> [--period=5m] [--num-workers=5]"
                return 1
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$tg_token" ]; then
        echo "Error: --tg-token is required"
        echo "Usage: lol serve --tg-token=<token> --tg-chat-id=<id> [--period=5m] [--num-workers=5]"
        return 1
    fi

    if [ -z "$tg_chat_id" ]; then
        echo "Error: --tg-chat-id is required"
        echo "Usage: lol serve --tg-token=<token> --tg-chat-id=<id> [--period=5m] [--num-workers=5]"
        return 1
    fi

    lol_cmd_serve "$period" "$tg_token" "$tg_chat_id" "$num_workers"
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
