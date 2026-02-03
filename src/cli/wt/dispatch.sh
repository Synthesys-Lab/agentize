#!/usr/bin/env bash
# wt CLI main dispatcher
# Entry point and help routing

# Log version information to stderr
_wt_log_version() {
    # Skip logging in --complete mode
    if [ "$1" = "--complete" ]; then
        return 0
    fi

    local git_dir="."
    local branch="unknown"
    local hash="unknown"

    if command -v git >/dev/null 2>&1; then
        git_dir=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
        branch=$(git -C "$git_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        hash=$(git -C "$git_dir" rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
    fi

    echo "[agentize] $branch @$hash" >&2
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
