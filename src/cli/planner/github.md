# planner/github.sh Interface Documentation

## Purpose

Optional GitHub issue helpers for default issue creation; `--dry-run` skips issue creation. Encapsulates all `gh` CLI interactions so the pipeline module only needs to call `_planner_issue_create` and `_planner_issue_publish` without knowing the `gh` API details.

## Private Helpers

| Function | Purpose |
|----------|---------|
| `_planner_gh_available` | Check if `gh` CLI is installed and authenticated |
| `_planner_issue_create` | Create a placeholder GitHub issue with `[plan] placeholder:` and a truncated feature title |
| `_planner_issue_publish` | Update issue body with consensus plan and add `agentize:plan` label |

## Design Rationale

All GitHub interactions are isolated in this module to keep the pipeline logic (`pipeline.sh`) independent of GitHub. When `gh` is unavailable or fails, each function returns non-zero and logs a warning, allowing the pipeline to fall back to timestamp-based artifacts without any error propagation.
