# planner/github.sh Interface Documentation

## Purpose

Optional GitHub issue helpers for default issue creation and refine mode. `--dry-run` skips issue creation/publish. Encapsulates all `gh` CLI interactions so the pipeline module only needs to call `_planner_issue_create`, `_planner_issue_fetch`, and `_planner_issue_publish` without knowing the `gh` API details.

## Private Helpers

| Function | Purpose |
|----------|---------|
| `_planner_gh_available` | Check if `gh` CLI is installed and authenticated |
| `_planner_issue_create` | Create a placeholder GitHub issue with `[plan] placeholder:` and a truncated feature title |
| `_planner_issue_fetch` | Fetch issue body (and URL) for refinement runs |
| `_planner_issue_publish` | Update issue body with consensus plan and add `agentize:plan` label |

## Design Rationale

All GitHub interactions are isolated in this module to keep the pipeline logic (`pipeline.sh`) independent of GitHub. Creation and publishing log warnings and allow timestamp fallbacks when `gh` is unavailable. Refinement fetches are treated as required inputs so the pipeline can reuse existing issue context.
