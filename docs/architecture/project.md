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

## Kanban Design [^1]

We have two Kanban boards for plans (GitHub Issues) and implementations (Pull Requests).

### Issue Status Field

For issues, we use a `Status` field (Single Selection) to track lifecycle:
- `Proposed`: The issue is proposed but not yet approved.
  - All issues created by AI agents start with this status.
- `Approved`: The issue is approved and ready for implementation.
  - `/issue-to-impl` command requires issues to be `Approved`.
- `WIP`: The issue is being worked on.
  - Prevents multiple workers from working on the same issue.
- `PR Created`: A pull request has been created for the issue.
- `Abandoned`: The issue has been abandoned for one of these reasons:
  - After careful consideration, this addition does not make sense at the issue phase.
  - After implementation, we find it is not a good idea.
- `Dependency`: The issue is blocked by other issues.
- `Done`: The issue has been completed and merged.

We use a `Single Selection` field instead of labels because labels cannot enforce mutual exclusivity.

### Pull Request Status

For pull requests, we use the standard GitHub Projects workflow:
- `Initial Review`: The PR is created and waiting for review.
- `Changes Requested`: Changes are requested on the PR.
- `Dependency`: This PR is blocked for merging because of dependencies on other PRs.
- `Approved`: The PR is approved and ready to be merged.
- `Merged`: The PR has been merged.

[^1]: Kanban is **NOT** a Japanese word! 看 (kan4) means view, and 板 (ban3) means board. So Kanban literally means a "view board".