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
        *)
            echo "lol: AI-powered SDK CLI"
            echo ""
            echo "Usage:"
            echo "  lol init --name <name> --lang <lang> [--path <path>] [--source <path>]"
            echo "  lol update [--path <path>]"
            echo ""
            echo "Flags:"
            echo "  --name <name>     Project name (required for init)"
            echo "  --lang <lang>     Programming language: c, cxx, python (required for init)"
            echo "  --path <path>     Project path (optional, defaults to current directory)"
            echo "  --source <path>   Source code path relative to project root (optional)"
            echo ""
            echo "Examples:"
            echo "  lol init --name my-project --lang python --path /path/to/project"
            echo "  lol update                    # From project root or subdirectory"
            echo "  lol update --path /path/to/project"
            return 1
            ;;
    esac
}

_agentize_init() {
    local name=""
    local lang=""
    local path=""
    local source=""

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
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>]"
                return 1
                ;;
        esac
    done

    # Validate required flags
    if [ -z "$name" ]; then
        echo "Error: --name is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>]"
        return 1
    fi

    if [ -z "$lang" ]; then
        echo "Error: --lang is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>]"
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

    echo "Initializing SDK:"
    echo "  Name: $name"
    echo "  Language: $lang"
    echo "  Path: $path"
    if [ -n "$source" ]; then
        echo "  Source: $source"
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
        path="$PWD"
        while [ "$path" != "/" ]; do
            if [ -d "$path/.claude" ]; then
                break
            fi
            path="$(dirname "$path")"
        done

        # Check if .claude/ was found
        if [ ! -d "$path/.claude" ]; then
            echo "Error: No .claude/ directory found in current directory or parents"
            echo ""
            echo "Please run from a project with .claude/ or use --path flag:"
            echo "  lol update --path /path/to/project"
            return 1
        fi
    else
        # Convert to absolute path
        path="$(cd "$path" 2>/dev/null && pwd)" || {
            echo "Error: Invalid path '$path'"
            return 1
        }

        # Verify .claude/ exists
        if [ ! -d "$path/.claude" ]; then
            echo "Error: No .claude/ directory found at $path"
            return 1
        fi
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
