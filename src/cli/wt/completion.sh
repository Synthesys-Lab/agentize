#!/usr/bin/env bash
# wt CLI completion helper
# Returns newline-delimited lists for shell completion systems

# Shell-agnostic completion helper
# Returns newline-delimited lists for shell completion systems
wt_complete() {
    local topic="$1"

    case "$topic" in
        commands)
            echo "clone"
            echo "common"
            echo "init"
            echo "goto"
            echo "spawn"
            echo "list"
            echo "remove"
            echo "prune"
            echo "purge"
            echo "pathto"
            echo "rebase"
            echo "help"
            ;;
        spawn-flags)
            echo "--yolo"
            echo "--no-agent"
            echo "--headless"
            echo "--model"
            ;;
        remove-flags)
            echo "--delete-branch"
            echo "-D"
            echo "--force"
            ;;
        rebase-flags)
            echo "--headless"
            echo "--yolo"
            ;;
        goto-targets)
            # List available worktrees
            local common_dir
            common_dir=$(wt_common 2>/dev/null)
            if [ -n "$common_dir" ] && [ -d "$common_dir/trees" ]; then
                echo "main"
                find "$common_dir/trees" -maxdepth 1 -type d -name "issue-*" 2>/dev/null | \
                    xargs -n1 basename 2>/dev/null | \
                    sed 's/^issue-//' | \
                    sed 's/-.*$//'
            fi
            ;;
        *)
            # Unknown topic, return empty
            return 0
            ;;
    esac
}
