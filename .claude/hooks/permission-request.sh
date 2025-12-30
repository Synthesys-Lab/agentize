#!/usr/bin/env bash
# PermissionRequest hook for Claude Code
# Auto-approves safe operations when hands-off mode is enabled

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HANDS_OFF_CONFIG="$PROJECT_ROOT/.claude/hands-off.json"
LOG_DIR="$PROJECT_ROOT/.tmp/claude-hooks"
LOG_FILE="$LOG_DIR/auto-approvals.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging helper
log_decision() {
    local decision="$1"
    local reason="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] DECISION=$decision | REASON=$reason" >> "$LOG_FILE"
}

# Read JSON from stdin
read_json_input() {
    # Read all stdin into a variable
    JSON_INPUT=$(cat)
    echo "$JSON_INPUT"
}

# Extract field from JSON (simple grep-based parser)
extract_json_field() {
    local json="$1"
    local field="$2"

    # Extract value for field using grep and sed
    echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/.*\"\([^\"]*\)\".*/\1/" || echo ""
}

# Check if hands-off mode is enabled
is_hands_off_enabled() {
    if [ ! -f "$HANDS_OFF_CONFIG" ]; then
        return 1
    fi

    # Read enabled field from JSON
    local enabled
    enabled=$(grep -o '"enabled"[[:space:]]*:[[:space:]]*[a-z]*' "$HANDS_OFF_CONFIG" | sed 's/.*:[[:space:]]*//' || echo "false")

    if [ "$enabled" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Get current git branch
get_current_branch() {
    git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo ""
}

# Check if on main/master branch
is_main_branch() {
    local branch
    branch=$(get_current_branch)

    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        return 0
    else
        return 1
    fi
}

# Check if .milestones/ files would be staged by git add
check_milestones_staging() {
    local command="$1"

    # Only check for git add commands
    if ! echo "$command" | grep -q "git add"; then
        return 1
    fi

    # Check if .milestones/ directory exists and has files
    if [ ! -d "$PROJECT_ROOT/.milestones" ]; then
        return 1
    fi

    # Check if any milestone files exist
    if ! ls "$PROJECT_ROOT/.milestones/"*.md &>/dev/null; then
        return 1
    fi

    # Check current git status for untracked or modified milestone files
    if git -C "$PROJECT_ROOT" status --porcelain .milestones/ 2>/dev/null | grep -q ".milestones/"; then
        return 0
    fi

    return 1
}

# Check if tool/command is safe
is_safe_operation() {
    local tool="$1"
    local command="$2"

    # Safe read-only tools
    case "$tool" in
        Read|Glob|Grep|LSP)
            return 0
            ;;
        Write|Edit|NotebookEdit)
            # Reversible on non-main branches
            if ! is_main_branch; then
                return 0
            fi
            ;;
        Bash)
            # Check for safe bash commands
            if is_safe_bash_command "$command"; then
                return 0
            fi
            ;;
    esac

    return 1
}

# Check if bash command is safe
is_safe_bash_command() {
    local command="$1"

    # Destructive patterns to block
    local destructive_patterns=(
        "git push"
        "git reset --hard"
        "git reset --mixed"
        "rm -rf"
        "rm -fr"
        "mkfs"
        "dd if="
        "> /dev/"
        "curl.*|.*sh"
        "wget.*|.*sh"
    )

    for pattern in "${destructive_patterns[@]}"; do
        if echo "$command" | grep -qi "$pattern"; then
            return 1
        fi
    done

    # Safe git commands
    local safe_git_patterns=(
        "git add"
        "git commit"
        "git status"
        "git diff"
        "git log"
        "git show"
        "git branch"
        "git rev-parse"
    )

    # If it's a git command, only allow safe ones
    if echo "$command" | grep -q "^git "; then
        for pattern in "${safe_git_patterns[@]}"; do
            if echo "$command" | grep -qi "^$pattern"; then
                # Special check for git add with .milestones/
                if echo "$command" | grep -qi "git add"; then
                    if check_milestones_staging "$command"; then
                        return 1
                    fi
                fi
                return 0
            fi
        done
        # Git command not in safe list
        return 1
    fi

    # Non-git bash commands (build tools, etc.) are generally safe
    # Block known dangerous patterns but allow others
    return 0
}

# Main decision logic
make_decision() {
    local json_input="$1"

    # Extract tool and command
    local tool
    local command
    tool=$(extract_json_field "$json_input" "tool")

    # Try to extract command from parameters
    if echo "$json_input" | grep -q '"command"'; then
        command=$(extract_json_field "$json_input" "command")
    else
        command=""
    fi

    # Check if hands-off is enabled
    if ! is_hands_off_enabled; then
        log_decision "ask" "Hands-off mode disabled"
        echo '{"decision": "ask"}'
        return
    fi

    # Check if on main branch
    if is_main_branch; then
        log_decision "ask" "On main/master branch - hands-off disabled for safety"
        echo '{"decision": "ask"}'
        return
    fi

    # Check if operation is safe
    if is_safe_operation "$tool" "$command"; then
        log_decision "allow" "Safe operation: tool=$tool command=$command"
        echo '{"decision": "allow"}'
        return
    else
        log_decision "deny" "Unsafe operation: tool=$tool command=$command"
        echo '{"decision": "deny"}'
        return
    fi
}

# Main execution
main() {
    # Read JSON from stdin
    local json_input
    json_input=$(read_json_input)

    # Handle empty input
    if [ -z "$json_input" ]; then
        log_decision "ask" "Empty input received"
        echo '{"decision": "ask"}'
        exit 0
    fi

    # Make decision
    make_decision "$json_input"
}

# Run main
main
