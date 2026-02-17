#!/usr/bin/env bash
# lol CLI main dispatcher
# Entry point and help text

# Log version information to stderr
_lol_log_version() {
    local git_dir="${AGENTIZE_HOME:-.}"
    local branch="unknown"
    local hash="unknown"

    if command -v git >/dev/null 2>&1; then
        branch=$(git -C "$git_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        hash=$(git -C "$git_dir" rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
    fi

    echo "[agentize] $branch @$hash" >&2
}

# Main lol function
lol() {
    # Handle completion helper before AGENTIZE_HOME validation
    # This allows completion to work even outside agentize context
    if [ "$1" = "--complete" ]; then
        _lol_complete "$2"
        return 0
    fi

    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/setup.sh\""
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

    # Handle --version flag as alias for version subcommand
    if [ "$1" = "--version" ]; then
        _lol_log_version
        _lol_cmd_version
        return $?
    fi

    # Parse subcommand
    local subcommand="$1"
    [ $# -gt 0 ] && shift

    case "$subcommand" in
        upgrade)
            _lol_parse_upgrade "$@"
            ;;
        use-branch)
            _lol_parse_use_branch "$@"
            ;;
        project)
            _lol_parse_project "$@"
            ;;
        serve)
            _lol_parse_serve "$@"
            ;;
        claude-clean)
            _lol_parse_claude_clean "$@"
            ;;
        plan)
            _lol_parse_plan "$@"
            ;;
        simp)
            _lol_parse_simp "$@"
            ;;
        impl)
            _lol_parse_impl "$@"
            ;;
        usage)
            _lol_parse_usage "$@"
            ;;
        version)
            _lol_log_version
            _lol_cmd_version
            ;;
        *)
            _lol_log_version
            echo "lol: AI-powered SDK CLI"
            echo ""
            echo "Usage:"
            echo "  lol upgrade [--keep-branch]"
            echo "  lol use-branch <remote>/<branch>"
            echo "  lol use-branch <branch>"
            echo "  lol --version"
            echo "  lol project --create [--org <owner>] [--title <title>]"
            echo "  lol project --associate <owner>/<id>"
            echo "  lol project --automation [--write <path>]"
            echo "  lol serve"
            echo "  lol plan [--dry-run] [--verbose] [--editor] [--backend <provider:model>] [--refine <issue-no> [refinement-instructions]] [<feature-description>]"
            echo "  lol simp [file] [<description>]"
            echo "  lol simp [file] --focus \"<description>\""
            echo "  lol simp [file] --editor"
            echo "  lol impl <issue-no> [--backend <provider:model>] [--max-iterations <N>] [--yolo] [--wait-for-ci]"
            echo "  lol usage [--today | --week] [--cache] [--cost]"
            echo "  lol claude-clean [--dry-run]"
            echo ""
            echo "Flags:"
            echo "  --version           Display version information"
            echo "  --keep-branch       Keep current branch for upgrade (pulls upstream)"
            echo "  --create            Create new GitHub Projects v2 board (project)"
            echo "  --associate <owner>/<id>  Associate existing project board (project)"
            echo "  --automation        Generate automation workflow template (project)"
            echo "  --write <path>      Write automation template to file (project)"
            echo "  --org <owner>       GitHub owner: organization or user (project --create)"
            echo "  --title <title>     Project title (project --create)"
            echo "  --dry-run           Skip issue creation (plan) or preview changes (claude-clean)"
            echo "  --verbose           Print detailed stage logs (plan)"
            echo "  --editor            Open \$EDITOR to compose feature description (plan, simp)"
            echo "  --backend <provider:model> Backend override (plan, impl)"
            echo "  --focus             Focus description to guide simplification (simp)"
            echo "  --refine            Refine an existing plan issue (plan)"
            echo "  --wait-for-ci       Monitor PR mergeability and CI (impl)"
            echo ""
            echo "Server configuration (.agentize.local.yaml):"
            echo "  server.period       Polling interval (default: 5m)"
            echo "  server.num_workers  Max concurrent workers (default: 5)"
            echo ""
            echo "Planner configuration (.agentize.local.yaml):"
            echo "  planner.backend     Default backend for all stages (provider:model)"
            echo "  planner.understander Override understander stage backend"
            echo "  planner.bold        Override bold-proposer stage backend"
            echo "  planner.critique    Override critique stage backend"
            echo "  planner.reducer     Override reducer stage backend"
            echo ""
            echo "Impl configuration (.agentize.local.yaml):"
            echo "  impl.model          Default impl backend (provider:model)"
            echo "  impl.max_iter       Default max implementation iterations"
            echo ""
            echo "Examples:"
            echo "  lol upgrade                     # Upgrade agentize installation"
            echo "  lol upgrade --keep-branch       # Upgrade without switching branches"
            echo "  lol use-branch dev/feature      # Switch to a remote development branch"
            echo "  lol --version                   # Display version information"
            echo "  lol project --create --org my-org --title \"My Project\""
            echo "  lol project --associate my-org/3"
            echo "  lol project --associate my-username/1   # Personal account project"
            echo "  lol project --automation --write .github/workflows/add-to-project.yml"
            echo "  lol serve                       # Start server (config in .agentize.local.yaml)"
            echo "  lol claude-clean --dry-run      # Preview stale entries"
            echo "  lol claude-clean                # Remove stale entries"
            echo "  lol plan \"Add JWT auth\"        # Run planning pipeline"
            echo "  lol plan --dry-run \"Refactor\"  # Plan without creating issue"
            echo "  lol plan --refine 42 \"Tighten scope\""
            echo "  lol simp README.md              # Simplify a single file"
            echo "  lol simp --editor               # Compose focus description in your editor"
            echo "  lol simp \"Refactor for clarity\" # Simplify with focus description"
            echo "  lol plan --editor --dry-run     # Compose description in your editor"
            return 1
            ;;
    esac
}
