# planner/github.sh Interface Documentation

## Purpose

Legacy GitHub issue helpers for default issue creation and refine mode. The Python planner backend now owns issue creation and publish logic; this module is retained for reference and compatibility with older shell-only workflows.

## Private Helpers

| Function | Purpose |
|----------|---------|
| `_planner_gh_available` | Check if `gh` CLI is installed and authenticated |
| `_planner_issue_create` | Create a placeholder GitHub issue with `[plan] placeholder:` and a truncated feature title |
| `_planner_issue_fetch` | Fetch issue body (and URL) for refinement runs |
| `_planner_issue_publish` | Update issue body with consensus plan, apply `agentize:plan`, and create/retry once if the label is missing |

## Design Rationale

GitHub interactions remain isolated here to document the historical shell workflow and provide a fallback implementation when needed. The current `lol plan` execution path uses the Python backend for issue handling, but the same behaviors (placeholder creation, refinement fetch, and best-effort label application with create-if-missing retry) are preserved in the new implementation.
