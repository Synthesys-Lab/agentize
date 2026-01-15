---
name: setup-viewboard
description: Set up a GitHub Projects v2 board with agentize-compatible Status fields, labels, and automation workflows
argument-hint: "[--org <org-name>]"
---

# Setup Viewboard Command

Set up a GitHub Projects v2 board for agentize workflow integration.

Invoke the command: `/setup-viewboard [--org <org-name>]`

This command will:
1. Check `.agentize.yaml` for existing project association
2. Create or associate a GitHub Projects v2 board (via shared library)
3. Generate automation workflow file (via shared library)
4. Verify Status field options with guidance URL for missing options
5. Create agentize issue labels

## Inputs

- `$ARGUMENTS` (optional): `--org <org-name>` to specify the organization or user for the project board. Defaults to repository owner.

## Shared Library Functions

This command uses the shared project library at `src/cli/lol/project-lib.sh`. Source it and initialize context before calling:

```bash
source "$AGENTIZE_HOME/src/cli/lol/project-lib.sh"
project_init_context
```

Available functions:
- `project_preflight_check` - Verify gh CLI availability and authentication
- `project_read_metadata <key>` - Read value from .agentize.yaml project section
- `project_update_metadata <key> <value>` - Update .agentize.yaml project section
- `project_create [owner] [title]` - Create new project via GraphQL
- `project_associate <owner/id>` - Associate existing project via GraphQL
- `project_generate_automation [write_path]` - Generate workflow template
- `project_verify_status_options <owner> <project_id>` - Verify Status field options

## Workflow Steps

When this command is invoked, follow these steps:

### Step 0: Check gh CLI Availability

Run preflight check via shared library:

```bash
source "$AGENTIZE_HOME/src/cli/lol/project-lib.sh"
project_preflight_check
```

If check fails, inform the user:
```
Error: GitHub CLI (gh) is not installed or not authenticated.

Install from: https://github.com/cli/cli
Authenticate: gh auth login
```
Stop execution.

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract the `--org` flag value if provided.

If `--org <org-name>` is present, extract `<org-name>` as the target organization/user.

### Step 2: Check .agentize.yaml

Initialize project context and read metadata:

```bash
project_init_context
owner=$(project_read_metadata "org") || owner=""
project_id=$(project_read_metadata "id") || project_id=""
```

If `.agentize.yaml` does not exist:
```
Error: .agentize.yaml not found.

Please create .agentize.yaml with at minimum:
  project:
    name: <project-name>
    lang: <python|bash|c|cxx>
```
Stop execution.

### Step 3: Create or Validate Project Association

**If no existing project association** (`project.org` and `project.id` not present):

Create project via shared library:
```bash
project_create "$org_arg"
```

Where `$org_arg` is the `--org` value if provided, otherwise empty.

Inform the user:
```
Creating new GitHub Projects v2 board...
```

**If project association exists**:

Inform the user and proceed to next step:
```
Found existing project association: <org>/<id>

Proceeding with automation workflow and labels setup...
```

### Step 4: Generate Automation Workflow

Generate the automation workflow file via shared library:

```bash
project_generate_automation ".github/workflows/add-to-project.yml"
```

Inform the user:
```
Generated automation workflow: .github/workflows/add-to-project.yml

To enable automation, add a GitHub Actions secret:
  Name: ADD_TO_PROJECT_PAT
  Value: A personal access token with project scope
```

### Step 5: Verify and Create Status Field Options

Verify project Status field configuration and auto-create missing options:

```bash
project_verify_status_options "$owner" "$project_id"
```

The function:
- Reports configured Status options found
- Detects missing required options
- Automatically creates missing options via GraphQL
- Falls back to guidance URL if creation fails (permissions)

Required options: Proposed, Refining, Plan Accepted, In Progress, Done

### Step 6: Create Issue Labels

Create agentize-specific labels using the GitHub CLI:

```bash
gh label create "agentize:plan" --description "Issues with implementation plans" --color "0E8A16" --force
gh label create "agentize:refine" --description "Issues queued for refinement" --color "1D76DB" --force
gh label create "agentize:dev-req" --description "Developer request issues" --color "D93F0B" --force
gh label create "agentize:bug-report" --description "Bug report issues" --color "B60205" --force
```

Inform the user:
```
Created labels:
  - agentize:plan (green)
  - agentize:refine (blue)
  - agentize:dev-req (orange)
  - agentize:bug-report (red)
```

### Step 7: Summary

Display completion summary:

```
Setup complete!

Project: <org>/<id>
Workflow: .github/workflows/add-to-project.yml
Labels: agentize:plan, agentize:refine, agentize:dev-req, agentize:bug-report

See: docs/architecture/project.md for Status field configuration details.
```

## Error Handling

Following the project's philosophy, assume CLI tools are available. Cast errors to users for resolution.

Common error scenarios:
- `.agentize.yaml` not found → User must create it
- `gh` CLI not authenticated → User must run `gh auth login`
- Project creation fails → Shared library reports GraphQL error
- Status options missing → Guidance URL provided for manual configuration
- Label creation fails → `gh` will error with details
