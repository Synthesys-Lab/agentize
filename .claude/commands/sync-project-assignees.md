---
name: sync-project-assignees
description: Backfill assignees for all items in PolyArch Project 2 to the currently authenticated GitHub user using `@me`.
argument-hint: "[project-number] (default: 2)"
allowed-tools: Bash(gh project item-list:*), Bash(gh issue edit:*), Bash(gh pr edit:*), Bash(grep:*), Bash(awk:*), Bash(echo:*), Bash(date:*)
---

## Goal

Ensure every item in the target GitHub Project has the currently authenticated GitHub user assigned (issues/PRs). This is intended as a one-time backfill for Project 2 in the PolyArch org.

## Steps

### 1) Set project parameters

```bash
PROJECT_NUMBER="${1:-2}"
OWNER="PolyArch"

echo "Project: ${OWNER}/${PROJECT_NUMBER}"
echo "Assignee: @me (currently authenticated user)"
```

**Prerequisites**:
- Ensure `gh auth status` shows you're logged in
- If project commands fail with permissions, run `gh auth refresh -s project`

### 2) Backfill assignees for all items

This extracts issue/PR URLs from the project items and adds `@me` (currently authenticated user) as an assignee.

Notes:
- This **adds** the assignee; it does not remove existing assignees.
- Draft items without an issue/PR URL are skipped.
- Use process substitution to avoid subshell issues.

```bash
while IFS= read -r url; do
  case "$url" in
    */issues/*)
      echo "Assign issue: $url"
      gh issue edit "$url" --add-assignee "@me"
      ;;
    */pull/*)
      echo "Assign PR: $url"
      gh pr edit "$url" --add-assignee "@me"
      ;;
  esac
done < <(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -L 500 \
  | grep -oE 'https://github.com/[^"]+/(issues|pull)/[0-9]+' \
  | awk '!seen[$0]++')
```
