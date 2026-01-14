---
name: setup-viewboard
description: Set up a GitHub Projects v2 board with agentize-compatible Status fields, labels, and automation workflows
argument_hint: "[--org <org-name>]"
---

# Setup Viewboard Command

Set up a GitHub Projects v2 board for agentize workflow integration.

Invoke the command: `/setup-viewboard [--org <org-name>]`

This command will:
1. Check `.agentize.yaml` for existing project association
2. Create or associate a GitHub Projects v2 board
3. Generate automation workflow file
4. Create agentize issue labels
5. Remind user to verify Status field options

## Inputs

- `$ARGUMENTS` (optional): `--org <org-name>` to specify the organization or user for the project board. Defaults to repository owner.

## Workflow Steps

When this command is invoked, follow these steps:

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract the `--org` flag value if provided.

If `--org <org-name>` is present, extract `<org-name>` as the target organization/user.

### Step 2: Check .agentize.yaml

Read `.agentize.yaml` from the project root:

```bash
cat .agentize.yaml 2>/dev/null
```

Parse the file to check for existing `project.org` and `project.id` fields.

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

Run project creation:
```bash
lol project --create [--org <org-name>]
```

Include `--org <org-name>` only if provided in arguments.

Inform the user:
```
Creating new GitHub Projects v2 board...
```

**If project association exists**:

Inform the user:
```
Found existing project association: <org>/<id>

Validating project access...
```

Run validation:
```bash
lol project --associate <org>/<id>
```

### Step 4: Generate Automation Workflow

Create the automation workflow file:

```bash
lol project --automation --write .github/workflows/add-to-project.yml
```

Inform the user:
```
Generated automation workflow: .github/workflows/add-to-project.yml

To enable automation, add a GitHub Actions secret:
  Name: ADD_TO_PROJECT_PAT
  Value: A personal access token with project scope
```

### Step 5: Create Issue Labels

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

### Step 6: Remind Status Field Configuration

Inform the user about required Status field options:

```
Setup complete!

Please verify your project's Status field has these options:
  - Proposed (for new plans awaiting approval)
  - Refining (for plans being refined by /ultra-planner --refine)
  - Plan Accepted (for approved plans ready for implementation)
  - In Progress (for active work)
  - Done (for completed items)

These options integrate with the Board view columns.
See: docs/architecture/project.md for details.
```

## Error Handling

Following the project's philosophy, assume CLI tools are available. Cast errors to users for resolution.

Common error scenarios:
- `.agentize.yaml` not found → User must create it
- `lol` CLI not available → User must source `setup.sh`
- `gh` CLI not authenticated → User must run `gh auth login`
- Project creation fails → `lol project` will error with details
- Label creation fails → `gh` will error with details
