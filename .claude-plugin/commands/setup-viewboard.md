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
2. Create or associate a GitHub Projects v2 board via GraphQL
3. Generate automation workflow file
4. Verify and configure Status field options via GraphQL
5. Create agentize issue labels

## Inputs

- `$ARGUMENTS` (optional): `--org <org-name>` to specify the organization or user for the project board. Defaults to repository owner.

## Implementation Note

This command is self-contained using shared library functions from `src/cli/lol/project-lib.sh`. The core GitHub Projects v2 operations are provided by:

- `project_create` - Creates a new GitHub Projects v2 board
- `project_associate` - Associates with an existing project board
- `project_generate_automation` - Generates the automation workflow file
- `project_verify_status_options` - Verifies and configures Status field options

## Workflow Steps

When this command is invoked, follow these steps:

### Step 0: Check gh CLI Availability

Verify `gh` is installed and authenticated by running:

```bash
gh auth status
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

Read `.agentize.yaml` to check for existing project association under the `project` section:
- `project.org` - Organization or user owner
- `project.id` - Project number

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

1. Determine the owner: use `--org` value if provided, otherwise get repository owner via `gh repo view --json owner -q '.owner.login'`

2. Get owner's node ID via GraphQL:
```bash
gh api graphql -f query='
  query($login: String!) {
    user(login: $login) { id }
  }' -f login="OWNER_LOGIN"
```
(Use `organization` instead of `user` for org-owned projects)

3. Create project via GraphQL:
```bash
gh api graphql -f query='
  mutation($ownerId: ID!, $title: String!) {
    createProjectV2(input: {ownerId: $ownerId, title: $title}) {
      projectV2 { id number url }
    }
  }' -f ownerId="OWNER_NODE_ID" -f title="PROJECT_TITLE"
```

4. Update `.agentize.yaml` with `project.org` and `project.id` values

**If project association exists**:

Inform the user and proceed to next step:
```
Found existing project association: <org>/<id>

Proceeding with automation workflow and labels setup...
```

### Step 4: Generate Automation Workflow

Generate the automation workflow file at `.github/workflows/add-to-project.yml` with the following content (substitute `PROJECT_URL` with the actual project URL):

```yaml
name: Add to Project
on:
  issues:
    types: [opened]
jobs:
  add-to-project:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1.0.2
        with:
          project-url: PROJECT_URL
          github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
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

1. Get Status field ID (use `user` for user-owned projects, `organization` for org-owned):
```bash
gh api graphql -f query='
  query {
    user(login: "OWNER_LOGIN") {
      projectV2(number: PROJECT_NUMBER) {
        id
        field(name: "Status") {
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
  }'
```

Required options: Proposed, Plan Accepted, In Progress, Done

2. If the status options are not as expected, use the command below to configure the Status field:
```bash
gh api graphql -f query='
  mutation {
    updateProjectV2Field(input: {
      fieldId: "FIELD_ID"
      singleSelectOptions: [
        {name: "Proposed", color: PURPLE, description: "Newly proposed issue"}
        {name: "Plan Accepted", color: BLUE, description: "Plan has been accepted"}
        {name: "Todo", color: GREEN, description: "This item has not been started"}
        {name: "In Progress", color: ORANGE, description: "This is actively being worked on"}
        {name: "Done", color: GRAY, description: "This has been completed"}
      ]
    }) {
      projectV2Field {
        ... on ProjectV2SingleSelectField {
          id
          options {
            id
            name
            color
          }
        }
      }
    }
  }'
```


### Step 6: Create Issue Labels

Create agentize-specific labels using the GitHub CLI:

```bash
gh label create "agentize:plan" --description "Issues with implementation plans" --color "0E8A16" --force
gh label create "agentize:refine" --description "Issues queued for refinement" --color "1D76DB" --force
gh label create "agentize:dev-req" --description "Developer request issues" --color "D93F0B" --force
gh label create "agentize:bug-report" --description "Bug report issues" --color "B60205" --force
gh label create "agentize:pr" --description "PR created for implementation" --color "8B6EE8" --force
```

Inform the user:
```
Created labels:
  - agentize:plan (green)
  - agentize:refine (blue)
  - agentize:dev-req (orange)
  - agentize:bug-report (red)
  - agentize:pr (purple)
```

### Step 7: Summary

Display completion summary:

```
Setup complete!

Project: <org>/<id>
Workflow: .github/workflows/add-to-project.yml
Labels: agentize:plan, agentize:refine, agentize:dev-req, agentize:bug-report, agentize:pr

See: docs/architecture/project.md for Status field configuration details.
```

## Error Handling

Following the project's philosophy, assume CLI tools are available. Cast errors to users for resolution.

Common error scenarios:
- `.agentize.yaml` not found → User must create it
- `gh` CLI not authenticated → User must run `gh auth login`
- Project creation fails → GraphQL mutation returns error details
- Status options missing → Provide guidance for manual configuration
- Label creation fails → `gh` will error with details
