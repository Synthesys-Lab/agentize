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

### Configuring the Default Status Field

GitHub Projects v2 includes a built-in **Status** field that integrates natively with the Board view. The `lol project --automation` command configures this default Status field with agentize-specific options.

**Why use the default Status field?**

- **Board View Affinity**: GitHub's Board view is designed around the Status field—columns automatically map to Status options, and drag-and-drop updates the Status field seamlessly.
- **Built-in Automations**: GitHub's native automations (e.g., "Item closed → Done") work with the Status field out of the box.
- **No Custom Field Maintenance**: Using the built-in field eliminates the need to create and maintain custom fields.

**Status field options:**

| Option | Description | Board Column |
|--------|-------------|--------------|
| Proposed | Plan proposed by agentize, awaiting approval | Leftmost |
| Plan Accepted | Plan approved, ready for implementation | Second |
| In Progress | Actively being worked on | Third |
| Done | Implementation complete | Rightmost |

**Automatic configuration:**

The `lol project --automation --write` command automatically queries and configures the Status field options via GraphQL. If you need to manually add options, use the `updateProjectV2` mutation (see GitHub's GraphQL API documentation).

### Querying Issue Project Fields

Look up an issue's project field values (including Status):

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

This returns all project associations and their field values, allowing you to index issues by their status.

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

### Issue Status: Board View Integration

For issues, we use GitHub Projects v2's **default Status field** with 4 options that map directly to Board view columns:

| Status | Description | Board Column |
|--------|-------------|--------------|
| Proposed | Plan proposed by agentize, awaiting approval | Leftmost |
| Plan Accepted | Plan approved, ready for implementation | Second |
| In Progress | Actively being worked on | Third |
| Done | Implementation complete | Rightmost |

**Workflow:**

1. **Proposed**: All issues created by AI agents start with this status. Issues are under review or awaiting stakeholder approval.
2. **Plan Accepted**: The issue plan is approved and ready for implementation. `/issue-to-impl` command requires issues to be at this status.
3. **In Progress**: Implementation has started. Use **assignees** to indicate who is working on it, and **linked PRs** to track progress.
4. **Done**: Implementation is complete. GitHub's built-in automation can move issues here when they are closed.

**Why use the default Status field?**

- **Board View Affinity**: GitHub's Board view is designed around the Status field—columns automatically map to Status options, and drag-and-drop updates the Status field.
- **4 Clear States**: Covers the full lifecycle from proposal to completion without excessive granularity.
- **Built-in Automations**: GitHub's native automations (e.g., "Item closed → Done") work seamlessly.
- **No Custom Field**: Uses the built-in field instead of creating a custom "Stage" field, simplifying setup.

### Pull Request Status

For pull requests, we use the standard GitHub Projects workflow:
- `Initial Review`: The PR is created and waiting for review.
- `Changes Requested`: Changes are requested on the PR.
- `Dependency`: This PR is blocked for merging because of dependencies on other PRs.
- `Approved`: The PR is approved and ready to be merged.
- `Merged`: The PR has been merged.

[^1]: Kanban is **NOT** a Japanese word! 看 (kan4) means view, and 板 (ban3) means board. So Kanban literally means a "view board".