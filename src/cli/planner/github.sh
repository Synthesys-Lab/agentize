#!/usr/bin/env bash
# planner GitHub issue helpers
# Optional issue creation and publishing for --issue mode

# Check if gh CLI is available and authenticated
# Returns 0 if available, 1 otherwise
_planner_gh_available() {
    command -v gh >/dev/null 2>&1 || return 1
    gh auth status >/dev/null 2>&1 || return 1
    return 0
}

# Create a placeholder GitHub issue for the planning pipeline
# Usage: _planner_issue_create "<title>"
# Outputs: issue number on stdout, or empty string on failure
_planner_issue_create() {
    local title="$1"

    if ! _planner_gh_available; then
        echo "Warning: gh CLI not available or not authenticated, skipping issue creation" >&2
        return 1
    fi

    local trimmed="${title:0:50}"
    if [ ${#title} -gt 50 ]; then
        trimmed="${trimmed}..."
    fi
    local issue_url
    issue_url=$(gh issue create \
        --title "[plan] placeholder: ${trimmed}" \
        --body "$title" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ] || [ -z "$issue_url" ]; then
        echo "Warning: Failed to create GitHub issue: $issue_url" >&2
        return 1
    fi

    # Parse issue number from URL (https://github.com/owner/repo/issues/N)
    local issue_number
    issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')

    if [ -z "$issue_number" ]; then
        echo "Warning: Could not parse issue number from URL: $issue_url" >&2
        return 1
    fi

    # Store URL for pipeline rendering
    _PLANNER_ISSUE_URL="$issue_url"

    echo "$issue_number"
    return 0
}

# Fetch existing GitHub issue body for refinement
# Usage: _planner_issue_fetch "<issue-number>"
# Outputs: issue body on stdout; returns non-zero on failure
_planner_issue_fetch() {
    local issue_number="$1"

    if ! _planner_gh_available; then
        echo "Error: gh CLI not available or not authenticated; cannot refine issue #$issue_number" >&2
        return 1
    fi

    local issue_body
    issue_body=$(gh issue view "$issue_number" --json body -q .body 2>/dev/null)
    local body_exit=$?
    if [ $body_exit -ne 0 ]; then
        echo "Error: Failed to fetch issue #$issue_number body" >&2
        return 1
    fi

    local issue_url
    issue_url=$(gh issue view "$issue_number" --json url -q .url 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$issue_url" ]; then
        _PLANNER_ISSUE_URL="$issue_url"
    fi

    echo "$issue_body"
    return 0
}

# Publish the consensus plan to a GitHub issue
# Usage: _planner_issue_publish "<issue-number>" "<title>" "<body-file>"
# Returns 0 on success, 1 on failure (caller should log warning but not fail pipeline)
_planner_issue_publish() {
    local issue_number="$1"
    local title="$2"
    local body_file="$3"

    if ! _planner_gh_available; then
        echo "Warning: gh CLI not available, skipping issue publish" >&2
        return 1
    fi

    # Update issue title and body
    gh issue edit "$issue_number" \
        --title "[plan] $title" \
        --body-file "$body_file" >/dev/null 2>&1
    local edit_exit=$?

    if [ $edit_exit -ne 0 ]; then
        echo "Warning: Failed to update issue #$issue_number body" >&2
        return 1
    fi

    # Add agentize:plan label
    gh issue edit "$issue_number" \
        --add-label "agentize:plan" >/dev/null 2>&1
    local label_exit=$?

    if [ $label_exit -ne 0 ]; then
        echo "Warning: Failed to add agentize:plan label to issue #$issue_number" >&2
        # Non-fatal: body was already updated
    fi

    return 0
}
