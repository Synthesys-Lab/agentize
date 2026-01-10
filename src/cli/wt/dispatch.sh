#!/usr/bin/env bash
# wt CLI main dispatcher
# Entry point and help routing

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
            cmd_help
            ;;
        --complete)
            wt_complete "$@"
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            echo "Run 'wt help' for usage information" >&2
            return 1
            ;;
    esac
}
