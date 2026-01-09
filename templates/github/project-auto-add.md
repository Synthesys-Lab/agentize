# GitHub Projects Automation Workflow Template

This document explains how the `project-auto-add.yml` workflow template works and how to configure it for your project.

## Overview

The workflow provides automated issue lifecycle management for GitHub Projects v2:

1. **Auto-add**: Automatically adds new issues and PRs to your project board
2. **Status "Proposed"**: Sets newly opened issues to Status "Proposed" (using the default Status field)
3. **Auto-close**: Closes linked issues when PRs are merged

## Workflow Architecture

The template defines two independent jobs:

### Job 1: `add-to-project`

Runs when issues or PRs are opened.

**Trigger**: `issues.opened` or `pull_request.opened`

**For issues**:
- Adds issue to project board
- Sets the default `Status` field to `Proposed` using the `actions/add-to-project` action's built-in parameters

**For PRs**:
- Adds PR to project board
- Does not set any field values (PRs use separate status workflow)

**Technology**: Uses the `actions/add-to-project@v1.0.2` GitHub Action

### Job 2: `close-linked-issues`

Runs when PRs are closed and merged.

**Trigger**: `pull_request.closed` with `merged == true`

**Process**:
1. **Query linked issues**: Uses `closingIssuesReferences` GraphQL field to find issues that this PR closes
2. **Close issues**: Uses `gh issue close` command to close each linked issue with reason "completed"

**Technology**: Uses GitHub CLI (`gh`) for both GraphQL queries and issue closing

### Job 3: `archive-pr-on-merge`

Runs when PRs are closed and merged to archive the PR item from the project board.

**Trigger**: `pull_request.closed` with `merged == true`

**Process**:
1. **Fetch project node ID**: Queries organization's project by number to get the GraphQL node ID
2. **Find PR item**: Searches project items (paginated, 100 per page) to find the item matching the merged PR's node ID
3. **Archive item**: Calls `archiveProjectV2Item` mutation to archive the item if found

**Technology**: Uses GitHub CLI (`gh`) for GraphQL queries and mutations

**Why archive on merge?**
- Completed PRs clutter active board views
- Archiving keeps them searchable but out of the way
- Aligns with GitHub's recommended project hygiene practices

**Note**: This job only archives PR items. For broader lifecycle archival (e.g., closed issues), use GitHub's built-in auto-archive feature in project settings.

## Configuration Requirements

### Environment Variables

You must configure these values in the `env:` section:

```yaml
env:
  PROJECT_ORG: YOUR_ORG_HERE              # Your GitHub organization name
  PROJECT_ID: YOUR_PROJECT_ID_HERE        # Project number (e.g., 3)
```

**How to find these values**:

- **PROJECT_ORG and PROJECT_ID**: These are substituted automatically by `lol project --automation` when you have project metadata in `.agentize.yaml`

**Note:** The workflow uses the default Status field by name (`status-field: Status`), so no field IDs are required. The `actions/add-to-project` action resolves field names automatically.

### Repository Secret

You must create a Personal Access Token (PAT) and store it as a repository secret:

**Secret name**: `ADD_TO_PROJECT_PAT`

**Required permissions**:
- `project`: Read and write (for adding items and updating fields)
- `metadata`: Read-only (automatically granted)

**Creation**:
```bash
# Create the secret using GitHub CLI
gh secret set ADD_TO_PROJECT_PAT
# Paste your PAT when prompted
```

Or use the GitHub web interface: **Settings** > **Secrets and variables** > **Actions** > **New repository secret**

## How It Works: Technical Details

### Step 1: Add to Project (Issues)

When an issue is opened, the workflow:

1. Checks `github.event_name == 'issues'`
2. Calls `actions/add-to-project` with:
   - `project-url`: Constructed from `PROJECT_ORG` and `PROJECT_ID`
   - `github-token`: Uses the `ADD_TO_PROJECT_PAT` secret
   - `status-field: Status`: Tells the action to set the default Status field
   - `status-value: Proposed`: Sets the value to "Proposed"

The action handles all the GraphQL complexity internally.

### Step 2: Add to Project (PRs)

When a PR is opened, the workflow:

1. Checks `github.event_name == 'pull_request'`
2. Calls `actions/add-to-project` with:
   - `project-url`: Constructed from `PROJECT_ORG` and `PROJECT_ID`
   - `github-token`: Uses the `ADD_TO_PROJECT_PAT` secret
   - No `status-field`/`status-value` (PRs don't get initial Status value)

### Step 3: Close Linked Issues (PR Merge)

When a PR is merged, the workflow executes two bash script steps:

#### 3.1: Get Linked Issues

Queries GitHub's `closingIssuesReferences` field to find issues that this PR closes:

```graphql
query($owner: String!, $repo: String!, $prNumber: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $prNumber) {
      closingIssuesReferences(first: 10) {
        nodes {
          number
          id
        }
      }
    }
  }
}
```

**Why this works**: GitHub automatically parses PR body and commits for phrases like "Closes #42" and populates the `closingIssuesReferences` field. This is the same mechanism that auto-closes issues when PRs merge.

The script stores the result in `$GITHUB_OUTPUT` for the next step.

#### 3.2: Close Linked Issues

For each linked issue, the script simply closes it using GitHub CLI:

```bash
gh issue close $issue_number --reason "completed"
```

**Why this is simpler**: Instead of complex GraphQL mutations to update custom Stage fields, we delegate completion tracking to GitHub's native issue status (Open/Closed). This eliminates the need for:
- Project node ID lookup
- Project item ID lookup
- Stage field option ID configuration
- GraphQL mutation complexity

The close reason "completed" helps distinguish successful completion from abandoned issues (which would use "not planned" as the close reason).

## Customization

### Changing the Initial Status Value

To set newly opened issues to a different initial status:

```yaml
status-field: Status
status-value: Backlog  # Changed from "Proposed"
```

The `actions/add-to-project` action resolves field and option names automatically, so no field IDs are needed.

### Changing the Close Reason

To use a different close reason when PRs merge:

```bash
gh issue close $issue_number --reason "not planned"  # Changed from "completed"
```

Valid close reasons: `completed`, `not planned`

### Adding PR Status on Open

To set a Status value for newly opened PRs:

```yaml
- name: Add PR to project
  if: github.event_name == 'pull_request'
  uses: actions/add-to-project@v1.0.2
  with:
    project-url: https://github.com/orgs/${{ env.PROJECT_ORG }}/projects/${{ env.PROJECT_ID }}
    github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
    status-field: Status
    status-value: In Review  # Add this
```

## Troubleshooting

### "Field not found" errors

**Symptom**: Workflow fails with error about field not found

**Cause**: The specified `status-field` name doesn't match any field in the project

**Fix**: Verify that the Status field exists in your project. Check the field name exactly matches (case-sensitive)

### Issues not being closed

**Symptom**: PR merges but linked issues remain open

**Possible causes**:

1. **No "Closes #N" reference**: GitHub's `closingIssuesReferences` requires explicit closing keywords in the PR description or commits. Ensure your PR body includes "Closes #N" or similar.

2. **PAT permissions**: Verify `ADD_TO_PROJECT_PAT` has permission to close issues in the repository.

3. **Issue already closed**: The script will skip issues that are already closed (no error, just logged).

### Permission denied errors

**Symptom**: Workflow fails with 403 or permission denied

**Causes**:
- PAT expired
- PAT doesn't have `project` write permission
- PAT's organization access was revoked

**Fix**: Create a new PAT with correct permissions and update the `ADD_TO_PROJECT_PAT` secret

### Rate limiting

**Symptom**: Workflow fails with rate limit errors

**Cause**: Too many GraphQL queries in short time (large batch of merged PRs)

**Mitigation**: GitHub Actions have higher rate limits than user accounts. This is rare but can happen with rapid PR merges.

**Fix**: Wait for rate limit to reset (typically 1 hour) or stagger PR merges

## Limitations

1. **10 linked issues maximum**: The `closingIssuesReferences` query uses `first: 10`. If a PR closes more than 10 issues, only the first 10 will be updated.

2. **Organization projects only**: The template uses `organization(login:)` query. For user projects, modify the GraphQL queries to use `user(login:)` instead.

3. **Single-select fields only**: The mutation uses `singleSelectOptionId`. For other field types (text, number, date), different mutation syntax is required.

4. **No cross-repository support**: Issues must be in the same repository as the PR. Cross-repo closing is not supported by `closingIssuesReferences`.

5. **PR archival only**: The `archive-pr-on-merge` job only archives merged PR items. Manual issue closing, abandoned PRs, and other lifecycle events are not archived. Use GitHub's built-in auto-archive for broader coverage.

6. **Large projects pagination**: PR item lookup iterates up to 5 pages (500 items). For very large projects with more than 500 active items, the PR may not be found and archival will be skipped (logged but no error).

## Reference Links

- [actions/add-to-project documentation](https://github.com/actions/add-to-project)
- [GitHub GraphQL API - Projects v2](https://docs.github.com/en/graphql/reference/objects#projectv2)
- [GitHub auto-linking issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue)
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

## See Also

- [`docs/workflows/github-projects-automation.md`](../../docs/workflows/github-projects-automation.md) - Full automation setup guide
- [`docs/architecture/project.md`](../../docs/architecture/project.md) - Project field management and GraphQL queries
- [`docs/cli/lol.md`](../../docs/cli/lol.md) - CLI reference for `lol project` commands
