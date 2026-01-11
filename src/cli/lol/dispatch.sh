#!/usr/bin/env bash
# lol CLI main dispatcher
# Entry point and help text

# Main lol function
lol() {
    # Handle completion helper before AGENTIZE_HOME validation
    # This allows completion to work even outside agentize context
    if [ "$1" = "--complete" ]; then
        lol_complete "$2"
        return 0
    fi

    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/setup.sh\""
        return 1
    fi

    # Check if AGENTIZE_HOME is a valid directory
    if [ ! -d "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME does not point to a valid directory"
        echo "  Current value: $AGENTIZE_HOME"
        echo ""
        echo "Please set AGENTIZE_HOME to your agentize repository path:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        return 1
    fi

    # Check if Makefile exists
    if [ ! -f "$AGENTIZE_HOME/Makefile" ]; then
        echo "Error: Makefile not found at $AGENTIZE_HOME/Makefile"
        echo "  AGENTIZE_HOME may not point to a valid agentize repository"
        return 1
    fi

    # Handle --version flag as alias for version subcommand
    if [ "$1" = "--version" ]; then
        lol_cmd_version
        return $?
    fi

    # Parse subcommand
    local subcommand="$1"
    [ $# -gt 0 ] && shift

    case "$subcommand" in
        apply)
            _lol_parse_apply "$@"
            ;;
        init)
            _lol_parse_init "$@"
            ;;
        update)
            _lol_parse_update "$@"
            ;;
        upgrade)
            _lol_parse_upgrade "$@"
            ;;
        project)
            _lol_parse_project "$@"
            ;;
        serve)
            _lol_parse_serve "$@"
            ;;
        claude-clean)
            _lol_parse_claude_clean "$@"
            ;;
        usage)
            _lol_parse_usage "$@"
            ;;
        version)
            lol_cmd_version
            ;;
        *)
            echo "lol: AI-powered SDK CLI"
            echo ""
            echo "Usage:"
            echo "  lol apply --init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
            echo "  lol apply --update [--path <path>]"
            echo "  lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
            echo "  lol update [--path <path>]"
            echo "  lol upgrade"
            echo "  lol --version"
            echo "  lol project --create [--org <org>] [--title <title>]"
            echo "  lol project --associate <org>/<id>"
            echo "  lol project --automation [--write <path>]"
            echo "  lol serve --tg-token=<token> --tg-chat-id=<id> [--period=5m]"
            echo "  lol usage [--today | --week]"
            echo "  lol claude-clean [--dry-run]"
            echo ""
            echo "Flags:"
            echo "  --version           Display version information"
            echo "  --init              Use init mode (apply only, requires --name and --lang)"
            echo "  --update            Use update mode (apply only)"
            echo "  --name <name>       Project name (required for init)"
            echo "  --lang <lang>       Programming language: c, cxx, python (required for init)"
            echo "  --path <path>       Project path (optional, defaults to current directory)"
            echo "  --source <path>     Source code path relative to project root (optional)"
            echo "  --metadata-only     Create only .agentize.yaml without SDK templates (optional, init only)"
            echo "  --create            Create new GitHub Projects v2 board (project)"
            echo "  --associate <org>/<id>  Associate existing project board (project)"
            echo "  --automation        Generate automation workflow template (project)"
            echo "  --write <path>      Write automation template to file (project)"
            echo "  --org <org>         GitHub organization (project --create)"
            echo "  --title <title>     Project title (project --create)"
            echo "  --tg-token=<token>  Telegram bot token (serve, required)"
            echo "  --tg-chat-id=<id>   Telegram chat ID (serve, required)"
            echo "  --period=<period>   Polling interval (serve, default: 5m)"
            echo "  --dry-run           Preview changes without modifying (claude-clean)"
            echo ""
            echo "Examples:"
            echo "  lol apply --init --name my-project --lang python --path /path/to/project"
            echo "  lol apply --update --path /path/to/project"
            echo "  lol init --name my-project --lang python --path /path/to/project"
            echo "  lol update                    # From project root or subdirectory"
            echo "  lol update --path /path/to/project"
            echo "  lol upgrade                   # Upgrade agentize installation"
            echo "  lol --version                 # Display version information"
            echo "  lol project --create --org Synthesys-Lab --title \"My Project\""
            echo "  lol project --associate Synthesys-Lab/3"
            echo "  lol project --automation --write .github/workflows/add-to-project.yml"
            echo "  lol serve --tg-token=xxx --tg-chat-id=xxx --period=30s"
            echo "  lol claude-clean --dry-run    # Preview stale entries"
            echo "  lol claude-clean              # Remove stale entries"
            return 1
            ;;
    esac
}
