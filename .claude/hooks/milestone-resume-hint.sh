#!/usr/bin/env bash
# Milestone resume hint helper for session-init hook
# Emits a resume hint when CLAUDE_HANDSOFF=true and a milestone exists

set -euo pipefail

# Check if CLAUDE_HANDSOFF is enabled (strict boolean check)
is_handsoff_enabled() {
    case "${CLAUDE_HANDSOFF:-}" in
        true|1|yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Extract issue number from branch name (pattern: issue-{N}-*)
extract_issue_number() {
    local branch="$1"
    if [[ "$branch" =~ ^issue-([0-9]+)- ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Find latest milestone file for an issue
find_latest_milestone() {
    local issue_num="$1"
    local milestones_dir=".milestones"

    if [[ ! -d "$milestones_dir" ]]; then
        return 1
    fi

    # Find all milestone files for this issue and sort by version
    local latest_milestone
    latest_milestone=$(ls -1 "$milestones_dir/issue-$issue_num-milestone-"*.md 2>/dev/null | sort -V | tail -n 1)

    if [[ -n "$latest_milestone" && -f "$latest_milestone" ]]; then
        echo "$latest_milestone"
        return 0
    fi

    return 1
}

# Extract milestone number from filename
extract_milestone_number() {
    local filepath="$1"
    if [[ "$filepath" =~ milestone-([0-9]+)\.md$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Main logic
main() {
    # Only show hint if hands-off mode is enabled
    if ! is_handsoff_enabled; then
        exit 0
    fi

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        exit 0
    fi

    # Get current branch
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || true)
    if [[ -z "$current_branch" ]]; then
        exit 0
    fi

    # Check if branch matches issue pattern
    local issue_num
    if ! issue_num=$(extract_issue_number "$current_branch"); then
        exit 0
    fi

    # Find latest milestone for this issue
    local milestone_file
    if ! milestone_file=$(find_latest_milestone "$issue_num"); then
        exit 0
    fi

    # Extract milestone number
    local milestone_num
    if ! milestone_num=$(extract_milestone_number "$milestone_file"); then
        exit 0
    fi

    # Display resume hint
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Milestone Resume Hint"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Branch: $current_branch"
    echo "  Latest milestone: $milestone_file"
    echo ""
    echo "  To resume implementation:"
    echo "    \"Continue from the latest milestone\""
    echo "    \"Resume implementation\""
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

main "$@"
