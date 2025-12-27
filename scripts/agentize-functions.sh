#!/usr/bin/env bash
# Cross-project agentize shell function
# Provides ergonomic init/update commands for agentize operations

agentize() {
    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/scripts/agentize-functions.sh\""
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
            echo "agentize: AI-powered SDK wrapper"
            echo ""
            echo "Usage:"
            echo "  agentize init --name <name> --lang <lang> [--path <path>]"
            echo "  agentize update [--path <path>]"
            echo ""
            echo "Examples:"
            echo "  agentize init --name my-project --lang python --path /path/to/project"
            echo "  agentize update                    # From project root or subdirectory"
            echo "  agentize update --path /path/to/project"
            return 1
            ;;
    esac
}

_agentize_init() {
    local name=""
    local lang=""
    local path=""

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
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: agentize init --name <name> --lang <lang> [--path <path>]"
                return 1
                ;;
        esac
    done

    # Validate required flags
    if [ -z "$name" ]; then
        echo "Error: --name is required"
        echo "Usage: agentize init --name <name> --lang <lang> [--path <path>]"
        return 1
    fi

    if [ -z "$lang" ]; then
        echo "Error: --lang is required"
        echo "Usage: agentize init --name <name> --lang <lang> [--path <path>]"
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

    echo "Initializing agentize SDK:"
    echo "  Name: $name"
    echo "  Language: $lang"
    echo "  Path: $path"
    echo ""

    # Call make agentize from AGENTIZE_HOME
    (
        cd "$AGENTIZE_HOME" || {
            echo "Error: Failed to change directory to $AGENTIZE_HOME"
            return 1
        }

        make agentize \
            AGENTIZE_PROJECT_NAME="$name" \
            AGENTIZE_PROJECT_PATH="$path" \
            AGENTIZE_PROJECT_LANG="$lang" \
            AGENTIZE_MODE="init"
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
                echo "Usage: agentize update [--path <path>]"
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
            echo "  agentize update --path /path/to/project"
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

    echo "Updating agentize SDK:"
    echo "  Path: $path"
    echo ""

    # Call make agentize from AGENTIZE_HOME
    (
        cd "$AGENTIZE_HOME" || {
            echo "Error: Failed to change directory to $AGENTIZE_HOME"
            return 1
        }

        make agentize \
            AGENTIZE_PROJECT_PATH="$path" \
            AGENTIZE_MODE="update"
    )
}
