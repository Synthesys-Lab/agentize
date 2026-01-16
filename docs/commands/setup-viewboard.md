# /setup-viewboard Command

Set up a GitHub Projects v2 board for agentize workflow integration.

## Synopsis

```
/setup-viewboard [--org <org-name>]
```

## Description

The `/setup-viewboard` command provides a self-contained setup for GitHub Projects v2 boards with agentize-compatible Status fields, labels, and automation workflows. It uses `gh` GraphQL operations directly via the shared project library (`src/cli/lol/project-lib.sh`) without calling `lol project` CLI commands.

## Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--org <org-name>` | No | Repository owner | GitHub organization or personal user login for the project board |

## Workflow

The command performs the following steps:

0. **Check `gh` CLI availability**: Verify `gh` is installed. If not, direct user to https://github.com/cli/cli for installation.

1. **Check `.agentize.yaml`**: Read existing `project.org` and `project.id` fields to detect an existing project association.

2. **Create or Associate Project Board**:
   - If no association exists: Create project via GraphQL (`project_create`)
   - If association exists: Validate project via GraphQL (`project_associate`)

3. **Generate Automation Workflow**: Generate workflow via `project_generate_automation` and write to `.github/workflows/add-to-project.yml`

4. **Verify and Create Status Field Options**: Query project Status field via GraphQL and auto-create missing options:
   - If options are missing: Automatically create them via `createProjectV2FieldOption` mutation
   - If auto-creation fails (permissions): Display guidance URL for manual configuration
   - Required options: Proposed, Refining, Plan Accepted, In Progress, Done

5. **Create Labels**: Create agentize issue labels using `gh label create --force`:
   - `agentize:plan` - Issues with implementation plans
   - `agentize:refine` - Issues queued for refinement
   - `agentize:dev-req` - Developer request issues (triage)
   - `agentize:bug-report` - Bug report issues (triage)

## Status Field Options

The command expects the GitHub Projects v2 board to have the following Status field options:

| Status | Description |
|--------|-------------|
| Proposed | Plan proposed by agentize, awaiting approval |
| Plan Accepted | Plan approved, ready for implementation |
| In Progress | Actively being worked on |
| Done | Implementation complete |

These status options integrate with the Board view columns. See [Project Management](../architecture/project.md) for details on Status field configuration.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth login`)
- `.agentize.yaml` present and writable
- GitHub Actions secret `ADD_TO_PROJECT_PAT` when enabling automation (see workflow file)

## Examples

### Create a user-owned project board

```
/setup-viewboard
```

Creates a project board owned by the current user (defaults to repository owner).

### Create an organization-owned project board

```
/setup-viewboard --org my-org
```

Creates a project board under the specified organization.

## Handsoff Mode Support

When `HANDSOFF_MODE=1`, `/setup-viewboard` operates as a tracked workflow with automatic permission passing for its specific `gh` CLI commands:

- `gh auth status` - Authentication verification
- `gh repo view --json owner -q ...` - Repository owner lookup
- `gh api graphql` - Project creation and configuration
- `gh label create --force` - Label creation

These permissions are automatically granted **only during the setup-viewboard workflow**, keeping the global permission model unchanged. See [Handsoff Mode](../feat/core/handsoff.md) for details on workflow tracking.

## See Also

- [Project Management](../architecture/project.md) - Architecture documentation
- [Metadata File](../architecture/metadata.md) - `.agentize.yaml` schema
- [lol project](../cli/lol.md#lol-project) - CLI interface (shares implementation with this command)
- [Handsoff Mode](../feat/core/handsoff.md) - Workflow tracking and auto-continuation
