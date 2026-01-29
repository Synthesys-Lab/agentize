#!/usr/bin/env bash
# lol CLI completion helper
# Returns newline-delimited lists for shell completion systems

# Shell-agnostic completion helper
# Returns newline-delimited lists for shell completion systems
lol_complete() {
    local topic="$1"

    case "$topic" in
        commands)
            echo "upgrade"
            echo "version"
            echo "project"
            echo "usage"
            echo "serve"
            echo "claude-clean"
            echo "plan"
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
            # No CLI flags - configuration is YAML-only (.agentize.local.yaml)
            ;;
        claude-clean-flags)
            echo "--dry-run"
            ;;
        usage-flags)
            echo "--today"
            echo "--week"
            echo "--cache"
            echo "--cost"
            ;;
        plan-flags)
            echo "--dry-run"
            echo "--verbose"
            echo "--refine"
            ;;
        *)
            # Unknown topic, return empty
            return 0
            ;;
    esac
}
