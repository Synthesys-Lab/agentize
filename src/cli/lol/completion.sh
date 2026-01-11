#!/usr/bin/env bash
# lol CLI completion helper
# Returns newline-delimited lists for shell completion systems

# Shell-agnostic completion helper
# Returns newline-delimited lists for shell completion systems
lol_complete() {
    local topic="$1"

    case "$topic" in
        commands)
            echo "apply"
            echo "init"
            echo "update"
            echo "upgrade"
            echo "version"
            echo "project"
            echo "usage"
            echo "serve"
            echo "claude-clean"
            ;;
        apply-flags)
            echo "--init"
            echo "--update"
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
        serve-flags)
            echo "--tg-token"
            echo "--tg-chat-id"
            echo "--period"
            echo "--num-workers"
            ;;
        claude-clean-flags)
            echo "--dry-run"
            ;;
        usage-flags)
            echo "--today"
            echo "--week"
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
