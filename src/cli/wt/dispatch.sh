#!/usr/bin/env bash
# wt CLI main dispatcher
# Entry point and help routing

# Log version information to stderr
_wt_log_version() {
    # Skip logging in --complete mode
    if [ "$1" = "--complete" ]; then
        return 0
    fi

    # Get version from git describe or short commit hash
    local version="unknown"
    if command -v git >/dev/null 2>&1; then
        # Try to get tag, fall back to short commit hash
        version=$(git describe --tags --always 2>/dev/null || echo "unknown")
    fi

    # Get full commit hash
    local commit="unknown"
    if command -v git >/dev/null 2>&1; then
        commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    fi

    # If AGENTIZE_HOME is not set, log as "standalone"
    if [ -z "$AGENTIZE_HOME" ]; then
        version="$version-standalone"
    fi

    echo "[agentize] $version @ $commit" >&2
}

# Main wt function
wt() {
    local command="$1"
    [ $# -gt 0 ] && shift

    case "$command" in
        clone)
            cmd_clone "$@"
            ;;
        common)
            cmd_common "$@"
            ;;
        init)
            cmd_init "$@"
            ;;
        goto)
            cmd_goto "$@"
            ;;
        spawn)
            cmd_spawn "$@"
            ;;
        remove)
            cmd_remove "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        prune)
            cmd_prune "$@"
            ;;
        purge)
            cmd_purge "$@"
            ;;
        pathto)
            wt_resolve_worktree "$@"
            ;;
        rebase)
            cmd_rebase "$@"
            ;;
        help|--help|-h|"")
            _wt_log_version "$command"
            cmd_help
            ;;
        --complete)
            wt_complete "$@"
            ;;
        *)
            _wt_log_version "$command"
            echo "Error: Unknown command: $command" >&2
            echo "Run 'wt help' for usage information" >&2
            return 1
            ;;
    esac
}
