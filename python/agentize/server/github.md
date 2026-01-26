# GitHub Module Documentation

## Overview

The `github.py` module provides GitHub issue/PR discovery and GraphQL helpers for the server module. It implements a **label-first discovery pattern** that efficiently identifies work items eligible for various automated workflows (implementation, refinement, rebase, review resolution).

## Architecture

### Label-First Discovery Pattern

Instead of querying all project items and filtering by labels, this module uses a **label-first approach**:

1. **Discovery phase**: Use `gh issue list --label <label>` to find candidates with specific labels
2. **Enrichment phase**: Perform per-issue GraphQL queries to fetch project status
3. **Filter phase**: Apply workflow-specific eligibility rules

This pattern is more efficient for large projects because:
- GitHub's label filtering is indexed and fast
- Only relevant issues are queried for status
- Avoids pagination issues with large project boards

### Workflow Eligibility Filters

Each workflow has a dedicated filter function that checks specific criteria:

| Workflow | Filter Function | Required Status | Required Labels |
|----------|----------------|-----------------|-----------------|
| Implementation | `filter_ready_issues` | Plan Accepted | `agentize:plan` |
| Refinement | `filter_ready_refinements` | Proposed | `agentize:plan` + `agentize:refine` |
| Feat-Request | `filter_ready_feat_requests` | Proposed | `agentize:dev-req`, NO `agentize:plan` |
| Rebase | `filter_conflicting_prs` | NOT Rebasing | `agentize:pr` (via PR discovery) |
| Review Resolution | `filter_ready_review_prs` | Proposed | `agentize:pr` (via PR discovery) |

## Key Functions

### Configuration

**`load_config()`**: Loads project configuration from `.agentize.yaml`, searching parent directories if not found in cwd. Returns `(org, project_id, remote_url)`.

**`get_repo_owner_name()`**: Resolves repository owner and name from git remote origin. Handles both SSH (`git@github.com:owner/repo.git`) and HTTPS (`https://github.com/owner/repo.git`) formats.

### GraphQL Helpers

**`lookup_project_graphql_id(org, project_number)`**: Converts owner and project number into a ProjectV2 GraphQL ID. Uses `repositoryOwner` query which works for both organizations and personal accounts. Results are cached to avoid repeated lookups.

**`query_issue_project_status(owner, repo, issue_no, project_id)`**: Fetches an issue's Status field value for the configured project. Returns the status string (e.g., "Plan Accepted", "Proposed") or empty string if not found.

### Issue Discovery

**`discover_candidate_issues(owner, repo)`**: Discovers open issues with `agentize:plan` label.

**`discover_candidate_feat_requests(owner, repo)`**: Discovers open issues with `agentize:dev-req` label.

**`query_project_items(org, project_number)`**: Combines discovery and enrichment to return a list of items with status for `agentize:plan` labeled issues.

**`query_feat_request_items(org, project_number)`**: Combines discovery and enrichment for `agentize:dev-req` labeled issues, including full label list for filtering.

### PR Discovery

**`discover_candidate_prs(owner, repo)`**: Discovers open PRs with `agentize:pr` label. Returns PR metadata including `number`, `headRefName`, `mergeable`, `body`, and `closingIssuesReferences`.

**`resolve_issue_from_pr(pr)`**: Resolves the linked issue number from PR metadata using fallback order:
1. Branch name pattern: `issue-<N>`
2. `closingIssuesReferences` field
3. PR body `#<N>` pattern

### Review Thread Detection

**`has_unresolved_review_threads(owner, repo, pr_no)`**: Checks if a PR has unresolved, non-outdated review threads. Uses `scripts/gh-graphql.sh review-threads` for the GraphQL query. Returns `True` if any eligible thread exists.

## Filter Functions Design

### Status-Based Concurrency Control

The filter functions implement **status-based concurrency control** to prevent duplicate work:

- **Proposed**: Issue is idle, eligible for new work
- **In Progress**: Worker is actively processing
- **Rebasing**: PR is being rebased
- **Plan Accepted**: Plan approved, ready for implementation

#### Concurrency Control Examples

**Review Resolution**: `filter_ready_review_prs` only accepts PRs whose linked issue has `Status == 'Proposed'`. When `spawn_review_resolution` starts, it sets status to "In Progress", preventing other workers from picking up the same PR.

**Feat-Request Planning**: `filter_ready_feat_requests` requires `Status == 'Proposed'` for issues with `agentize:dev-req` label. When `spawn_feat_request` starts, it sets status to "In Progress" before spawning the planning session. After completion, `_cleanup_feat_request` resets the status to "Proposed". This prevents duplicate planning sessions from spawning during each polling cycle.

### Debug Output

All filter functions support debug logging for detailed decision tracking. Enable debug mode in your `.agentize.local.yaml`:

```yaml
handsoff:
  debug: true
```

Output includes per-item decisions with reasons and summary statistics.

## Caching

**`_project_id_cache`**: Module-level cache for project GraphQL IDs. Keyed by `(org, project_number)` tuple. Avoids repeated GraphQL lookups for the same project within a server session.
