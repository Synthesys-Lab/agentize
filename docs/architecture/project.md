# Project Management

In `./metadata.md`, we discussed the metadata file `.agentize.yaml` that stores
the GitHub Projects v2 association information:

```yaml
project:
   org: Synthesys-Lab
   id: 3
```

This section discusses how to integrate GitHub Projects v2 with an `agentize`d project.

## Creating or Associating a Project

Create a new GitHub Projects v2 board and associate it with the current repository:
```bash
lol project --create [--org <org>] [--title <title>]
```

Associate an existing GitHub Projects v2 board with the current repository:
```bash
lol project --associate <org>/<id>
```

Both commands update `.agentize.yaml` with `project.org` and `project.id` fields.

## Automation

The `lol project` command provides project association but does not automatically install automation workflows. To automatically add issues and pull requests to your project board, see the [GitHub Projects automation guide](../workflows/github-projects-automation.md).

Generate an automation workflow template:
```bash
lol project --automation [--write <path>]
```

## Project Field Management

Before configuring your Kanban board, you need to create custom fields in GitHub Projects v2 using the GraphQL API.

### Converting Project Number to GraphQL ID

Convert the project number (e.g., `3` from `.agentize.yaml`) to its GraphQL ID:

```bash
gh api graphql -f query='
query {
  organization(login: "Synthesys-Lab") {
    projectV2(number: 3) {
      id
      title
    }
  }
}'
```

### Creating Custom Fields

Use the returned GraphQL ID (`PVT_xxx`) to create custom fields:

```bash
gh api graphql -f query='
mutation {
  createProjectV2Field(
    input: {
      projectId: "PVT_xxx"
      dataType: SINGLE_SELECT
      name: "Stage"
      singleSelectOptions: [
        { name: "proposed" }
        { name: "accepted" }
      ]
    }
  ) {
    projectV2Field {
      id
      name
    }
  }
}'
```

**Note:** The Stage field uses a two-layer model for tracking work:
- **Stage field (Approval tracking)**: `proposed` → `accepted`
- **GitHub Issue status (Completion tracking)**: `Open` → `Closed`

This design delegates completion tracking to GitHub's native issue lifecycle, keeping the custom Stage field focused solely on approval workflow.

### Querying Issue Project Fields

Look up an issue's project field values (including Stage):

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    issue(number:$number) {
      id
      title
      projectItems(first: 20) {
        nodes {
          id
          project {
            id
            title
            number
          }
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { name } }
                name
              }
            }
          }
        }
      }
    }
  }
}' -f owner='OWNER' -f repo='REPO' -F number=ISSUE_NUMBER
```

This returns all project associations and their field values, allowing you to index issues by their stage.

### Listing Field and Option IDs for Automation

GitHub Actions workflows that update project fields require field and option IDs. To list all fields and their options for automation configuration:

```bash
gh api graphql -f query='
query {
  node(id: "PVT_xxx") {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}'
```

Replace `PVT_xxx` with your project's GraphQL ID (obtained via the project number query in "Converting Project Number to GraphQL ID" section).

This returns all single-select fields (like Stage, Status, Priority) along with their option IDs, which are needed for automation workflows that update field values via GraphQL mutations.

### Dumping Project Configuration

Automation workflows can dump and version control your project field configuration for reproducibility.

## Kanban Design [^1]

We have two Kanban boards for plans (GitHub Issues) and implementations (Pull Requests).

### Issue Status: Two-Layer Model

For issues, we use a **two-layer model** that separates approval tracking from completion tracking:

**Layer 1: Stage Field (Approval Workflow)**

A `Stage` custom field (Single Selection) tracks whether an issue is approved for implementation:
- `proposed`: The issue is proposed but not yet approved for implementation.
  - All issues created by AI agents start with this stage.
  - Issues at this stage are under review or awaiting stakeholder approval.
- `accepted`: The issue is approved and ready for implementation.
  - `/issue-to-impl` command requires issues to be at `accepted` stage.
  - Moving an issue to this stage signals green light for development work.

**Layer 2: GitHub Issue Status (Completion Tracking)**

GitHub's native issue status tracks implementation progress and completion:
- `Open`: Issue is either awaiting implementation or currently in progress.
  - Use **assignees** to indicate work-in-progress (assigned = someone is working on it).
  - Use **linked PRs** to track implementation progress.
- `Closed`: Issue implementation is complete or abandoned.
  - Use close reason `completed` when PR is merged.
  - Use close reason `not planned` when issue is abandoned or no longer relevant.

**Why this design?**

- **Simplicity**: Only 2 Stage options instead of 6, reducing cognitive overhead.
- **Delegation**: Leverages GitHub's native issue lifecycle instead of duplicating it in custom fields.
- **Clarity**: Separates "Is this approved?" (Stage) from "Is this done?" (Issue status).
- **Automation**: GitHub automatically closes issues when linked PRs merge, no custom field updates needed.

We use a `Single Selection` field for Stage instead of labels because labels cannot enforce mutual exclusivity.

### Pull Request Status

For pull requests, we use the standard GitHub Projects workflow:
- `Initial Review`: The PR is created and waiting for review.
- `Changes Requested`: Changes are requested on the PR.
- `Dependency`: This PR is blocked for merging because of dependencies on other PRs.
- `Approved`: The PR is approved and ready to be merged.
- `Merged`: The PR has been merged.

[^1]: Kanban is **NOT** a Japanese word! 看 (kan4) means view, and 板 (ban3) means board. So Kanban literally means a "view board".