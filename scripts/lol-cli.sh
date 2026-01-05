#!/usr/bin/env bash
# Cross-project lol shell function
# Provides ergonomic init/update commands for AI-powered SDK operations

# Shell-agnostic completion helper
# Returns newline-delimited lists for shell completion systems
lol_complete() {
    local topic="$1"

    case "$topic" in
        commands)
            echo "init"
            echo "update"
            echo "project"
            ;;
        init-flags)
            echo "--name"
            echo "--lang"
            echo "--path"
            echo "--source"
            echo "--metadata-only"
            ;;
        update-flags)
            echo "--path"
            ;;
        project-modes)
            echo "--create"
            echo "--associate"
            echo "--automation"
            ;;
        project-create-flags)
            echo "--org"
            echo "--title"
            ;;
        project-automation-flags)
            echo "--write"
            ;;
        lang-values)
            echo "c"
            echo "cxx"
            echo "python"
            ;;
        *)
            # Unknown topic, return empty
            return 0
            ;;
    esac
}

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
    [ $# -gt 0 ] && shift

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
    local project_path=""
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
                project_path="$2"
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
    if [ -z "$project_path" ]; then
        project_path="$PWD"
    fi

    # Convert to absolute path
    project_path="$(cd "$project_path" 2>/dev/null && pwd)" || {
        echo "Error: Invalid path '$project_path'"
        return 1
    }

    if [ "$metadata_only" = "1" ]; then
        echo "Initializing metadata only:"
    else
        echo "Initializing SDK:"
    fi
    echo "  Name: $name"
    echo "  Language: $lang"
    echo "  Path: $project_path"
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
        export AGENTIZE_PROJECT_PATH="$project_path"
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
    local project_path=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                project_path="$2"
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
    if [ -z "$project_path" ]; then
        local search_path="$PWD"
        project_path=""
        while [ "$search_path" != "/" ]; do
            if [ -d "$search_path/.claude" ]; then
                project_path="$search_path"
                break
            fi
            search_path="$(dirname "$search_path")"
        done

        # If no .claude/ found, default to current directory with warning
        if [ -z "$project_path" ]; then
            project_path="$PWD"
            echo "Warning: No .claude/ directory found in current directory or parents"
            echo "  Defaulting to: $project_path"
            echo "  .claude/ will be created during update"
            echo ""
        fi
    else
        # Convert to absolute path
        project_path="$(cd "$project_path" 2>/dev/null && pwd)" || {
            echo "Error: Invalid path '$project_path'"
            return 1
        }

        # Allow missing .claude/ - it will be created during update
    fi

    echo "Updating SDK:"
    echo "  Path: $project_path"
    echo ""

    # Call agentize-update.sh directly with environment variables
    (
        export AGENTIZE_PROJECT_PATH="$project_path"
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
