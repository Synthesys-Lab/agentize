# /setup-viewboard Command

Set up a GitHub Projects v2 board for agentize workflow integration.

## Synopsis

```
/setup-viewboard [--org <org-name>]
```

## Description

The `/setup-viewboard` command provides a guided wrapper for setting up GitHub Projects v2 boards with agentize-compatible Status fields, labels, and automation workflows. It orchestrates the `lol project` CLI commands while guiding the user through the setup process.

## Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--org <org-name>` | No | Repository owner | GitHub organization or personal user login for the project board |

## Workflow

The command performs the following steps:

1. **Check `.agentize.yaml`**: Read existing `project.org` and `project.id` fields to detect an existing project association.

2. **Create or Associate Project Board**:
   - If no association exists: Run `lol project --create [--org <org-name>]`
   - If association exists: Confirm and optionally validate with `lol project --associate`

3. **Generate Automation Workflow**: Run `lol project --automation --write .github/workflows/add-to-project.yml`

4. **Create Labels**: Create agentize issue labels using `gh label create --force`:
   - `agentize:plan` - Issues with implementation plans
   - `agentize:refine` - Issues queued for refinement
   - `agentize:dev-req` - Developer request issues (triage)
   - `agentize:bug-report` - Bug report issues (triage)

5. **Remind Status Options**: Prompt user to verify the project's Status field options match the expected values (see below).

## Status Field Options

The command expects the GitHub Projects v2 board to have the following Status field options:

| Status | Description |
|--------|-------------|
| Proposed | Plan proposed by agentize, awaiting approval |
| Refining | Plan is being refined by `/ultra-planner --refine` |
| Plan Accepted | Plan approved, ready for implementation |
| In Progress | Actively being worked on |
| Done | Implementation complete |

These status options integrate with the Board view columns. See [Project Management](../architecture/project.md) for details on Status field configuration.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth login`)
- `.agentize.yaml` present and writable
- `lol` CLI available (source `setup.sh`)
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

## See Also

- [lol project](../cli/lol.md#lol-project) - CLI for project management
- [Project Management](../architecture/project.md) - Architecture documentation
- [Metadata File](../architecture/metadata.md) - `.agentize.yaml` schema
