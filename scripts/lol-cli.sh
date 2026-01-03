#!/usr/bin/env bash
# Cross-project lol shell function
# Provides ergonomic init/update commands for AI-powered SDK operations

lol() {
    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/scripts/lol-cli.sh\""
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

    # Parse subcommand
    local subcommand="$1"
    shift || true

    case "$subcommand" in
        init)
            _agentize_init "$@"
            ;;
        update)
            _agentize_update "$@"
            ;;
        project)
            _agentize_project "$@"
            ;;
        *)
            echo "lol: AI-powered SDK CLI"
            echo ""
            echo "Usage:"
            echo "  lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
            echo "  lol update [--path <path>]"
            echo "  lol project --create [--org <org>] [--title <title>]"
            echo "  lol project --associate <org>/<id>"
            echo "  lol project --automation [--write <path>]"
            echo ""
            echo "Flags:"
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
            echo ""
            echo "Examples:"
            echo "  lol init --name my-project --lang python --path /path/to/project"
            echo "  lol update                    # From project root or subdirectory"
            echo "  lol update --path /path/to/project"
            echo "  lol project --create --org Synthesys-Lab --title \"My Project\""
            echo "  lol project --associate Synthesys-Lab/3"
            echo "  lol project --automation --write .github/workflows/add-to-project.yml"
            return 1
            ;;
    esac
}

_agentize_init() {
    local name=""
    local lang=""
    local path=""
    local source=""
    local metadata_only="0"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                name="$2"
                shift 2
                ;;
            --lang)
                lang="$2"
                shift 2
                ;;
            --path)
                path="$2"
                shift 2
                ;;
            --source)
                source="$2"
                shift 2
                ;;
            --metadata-only)
                metadata_only="1"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
                return 1
                ;;
        esac
    done

    # Validate required flags
    if [ -z "$name" ]; then
        echo "Error: --name is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
        return 1
    fi

    if [ -z "$lang" ]; then
        echo "Error: --lang is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
        return 1
    fi

    # Use current directory if --path not provided
    if [ -z "$path" ]; then
        path="$PWD"
    fi

    # Convert to absolute path
    path="$(cd "$path" 2>/dev/null && pwd)" || {
        echo "Error: Invalid path '$path'"
        return 1
    }

    if [ "$metadata_only" = "1" ]; then
        echo "Initializing metadata only:"
    else
        echo "Initializing SDK:"
    fi
    echo "  Name: $name"
    echo "  Language: $lang"
    echo "  Path: $path"
    if [ -n "$source" ]; then
        echo "  Source: $source"
    fi
    if [ "$metadata_only" = "1" ]; then
        echo "  Mode: Metadata only (no templates)"
    fi
    echo ""

    # Call agentize-init.sh directly with environment variables
    (
        export AGENTIZE_PROJECT_NAME="$name"
        export AGENTIZE_PROJECT_PATH="$path"
        export AGENTIZE_PROJECT_LANG="$lang"
        if [ -n "$source" ]; then
            export AGENTIZE_SOURCE_PATH="$source"
        fi
        if [ "$metadata_only" = "1" ]; then
            export AGENTIZE_METADATA_ONLY="1"
        fi

        "$AGENTIZE_HOME/scripts/agentize-init.sh"
    )
}

_agentize_update() {
    local path=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                path="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol update [--path <path>]"
                return 1
                ;;
        esac
    done

    # If no path provided, find nearest .claude/ directory
    if [ -z "$path" ]; then
        local search_path="$PWD"
        path=""
        while [ "$search_path" != "/" ]; do
            if [ -d "$search_path/.claude" ]; then
                path="$search_path"
                break
            fi
            search_path="$(dirname "$search_path")"
        done

        # If no .claude/ found, default to current directory with warning
        if [ -z "$path" ]; then
            path="$PWD"
            echo "Warning: No .claude/ directory found in current directory or parents"
            echo "  Defaulting to: $path"
            echo "  .claude/ will be created during update"
            echo ""
        fi
    else
        # Convert to absolute path
        path="$(cd "$path" 2>/dev/null && pwd)" || {
            echo "Error: Invalid path '$path'"
            return 1
        }

        # Allow missing .claude/ - it will be created during update
    fi

    echo "Updating SDK:"
    echo "  Path: $path"
    echo ""

    # Call agentize-update.sh directly with environment variables
    (
        export AGENTIZE_PROJECT_PATH="$path"
        "$AGENTIZE_HOME/scripts/agentize-update.sh"
    )
}

_agentize_project() {
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
                    echo "Usage: lol project --create [--org <org>] [--title <title>]"
                    return 1
                fi
                mode="create"
                shift
                ;;
            --associate)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --associate with --create or --automation"
                    echo "Usage: lol project --associate <org>/<id>"
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
                echo "  lol project --create [--org <org>] [--title <title>]"
                echo "  lol project --associate <org>/<id>"
                echo "  lol project --automation [--write <path>]"
                return 1
                ;;
        esac
    done

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: Must specify --create, --associate, or --automation"
        echo "Usage:"
        echo "  lol project --create [--org <org>] [--title <title>]"
        echo "  lol project --associate <org>/<id>"
        echo "  lol project --automation [--write <path>]"
        return 1
    fi

    # Call agentize-project.sh with appropriate environment variables
    (
        export AGENTIZE_PROJECT_MODE="$mode"
        if [ -n "$org" ]; then
            export AGENTIZE_PROJECT_ORG="$org"
        fi
        if [ -n "$title" ]; then
            export AGENTIZE_PROJECT_TITLE="$title"
        fi
        if [ -n "$associate_arg" ]; then
            export AGENTIZE_PROJECT_ASSOCIATE="$associate_arg"
        fi
        if [ "$automation" = "1" ]; then
            export AGENTIZE_PROJECT_AUTOMATION="1"
        fi
        if [ -n "$write_path" ]; then
            export AGENTIZE_PROJECT_WRITE_PATH="$write_path"
        fi

        "$AGENTIZE_HOME/scripts/agentize-project.sh"
    )
}
