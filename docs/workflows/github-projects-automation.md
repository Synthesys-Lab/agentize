# GitHub Projects v2 Automation

This document describes how to set up automation for GitHub Projects v2 boards after creating or associating a project using `lol project`.

## Overview

The `lol project` command creates or associates a GitHub Projects v2 board with your repository by storing the project metadata in `.agentize.yaml`. Automation setup (automatically adding issues and pull requests to the project) is handled separately through GitHub's native features.

## Automation Methods

### Method 1: GitHub Built-in Auto-add Filters (Recommended)

GitHub Projects v2 provides built-in auto-add workflows that require no code or Actions setup.

**Setup steps:**

1. Open your project board on GitHub
2. Click the three-dot menu (⋯) in the top right
3. Select **Workflows**
4. Enable **Auto-add to project**
5. Configure filters:
   - **For issues:** `is:issue is:open repo:owner/repo`
   - **For pull requests:** `is:pr is:open repo:owner/repo`

**Advantages:**
- No GitHub Actions required
- No workflow file maintenance
- Works immediately
- No API rate limits

**Limitations:**
- Only supports basic filters
- Cannot run custom logic or set field values

### Method 2: GitHub Actions Workflow (Advanced)

For more control over automation (e.g., setting custom field values, complex filtering), use the `actions/add-to-project` action with GitHub GraphQL API for lifecycle management.

**Setup steps:**

1. Generate and configure the workflow template:
   ```bash
   lol project --automation --write .github/workflows/add-to-project.yml
   ```

   This command will:
   - Query the project's default Status field
   - Configure the Status field with agentize options (Proposed, Plan Accepted, In Progress, Done) if needed
   - Generate a workflow that uses `status-field: Status` and `status-value: Proposed`
   - Write the fully configured workflow to the specified path

2. Set up the Personal Access Token (see [Security: Personal Access Token (PAT)](#security-personal-access-token-pat) section below)

3. Commit and push:
   ```bash
   git add .github/workflows/add-to-project.yml
   git commit -m "Add GitHub Projects automation workflow"
   git push
   ```

4. Verify the workflow runs on the **Actions** tab

**Note:** If the command cannot access your project (e.g., not authenticated or project doesn't exist), it will generate a template with placeholder values that you'll need to configure manually. See [Manual Configuration](#manual-configuration) below.

**Template reference:** See [`templates/github/project-auto-add.yml`](../../templates/github/project-auto-add.yml)

**Automation capabilities:**
- Automatically adds new issues and PRs to the project board
- Sets Status to "Proposed" for newly opened issues (using the default Status field)
- Closes linked issues when associated PRs are merged (using GitHub's `closingIssuesReferences`)
- Archives merged PR items from the project board (declutters active views)
- Board view columns automatically reflect the 4 Status options

**Advantages:**
- Fine-grained control over automation logic
- Uses default Status field for Board view integration
- Native PR-to-issue linking via GitHub's closingIssuesReferences
- Supports complex filtering conditions
- No custom field creation needed—uses built-in Status field

**Limitations:**
- Requires workflow file maintenance
- Consumes GitHub Actions minutes
- May hit API rate limits on large repos
- Archives only merged PR items (manual issue archival not included; use GitHub's built-in auto-archive for broader lifecycle handling)

## Setting Custom Field Values

The generated workflow template automatically sets the Status field to "Proposed" for new issues using the `actions/add-to-project` action's built-in `status-field` and `status-value` parameters.

**For basic customization:**

Edit the generated workflow to change field names or values:
```yaml
- uses: actions/add-to-project@v1.0.2
  with:
    project-url: https://github.com/orgs/${{ env.PROJECT_ORG }}/projects/${{ env.PROJECT_ID }}
    github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
    # Customize the field name and value:
    status-field: Status  # Or "Stage", "Priority", etc.
    status-value: Proposed  # Or "Backlog", "To Do", etc.
```

**For advanced lifecycle automation:**

The template also includes a PR-merge job that closes linked issues when PRs are merged. This uses GitHub CLI's `gh issue close` command, which is simpler than GraphQL mutations and doesn't require option IDs.

See the [`actions/add-to-project` documentation](https://github.com/actions/add-to-project) for all available action parameters.

## Manual Configuration

**When is manual configuration needed?**

The `lol project --automation --write` command automatically configures the Status field for you. However, manual configuration may be needed if:
- You're not authenticated with GitHub CLI (`gh auth login`)
- The project doesn't exist or you don't have access to it
- The project's Status field options need manual adjustment

If automatic configuration fails, the command will generate a template with placeholder values and provide instructions for manual setup.

### Manual Field ID Lookup

The generated workflow template uses the `actions/add-to-project` action to set the Status field to "Proposed" for new issues. If you need to manually configure this, follow these steps.

**Step 1: Get your project's GraphQL ID**

Convert your project number to its GraphQL node ID:

```bash
gh api graphql -f query='
query {
  organization(login: "YOUR_ORG") {
    projectV2(number: YOUR_PROJECT_NUMBER) {
      id
      title
    }
  }
}'
```

Save the `id` value (e.g., `PVT_xxx`) for the next step.

**Step 2: List all fields**

Query all single-select fields (like Stage/Status):

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

**Step 3: Verify Status field options**

From the query output, locate the "Status" field and verify it has the expected options (Proposed, Plan Accepted, In Progress, Done). The `actions/add-to-project` action uses the field name ("Status") and option name ("Proposed") directly—no field IDs are needed in the workflow.

**Step 4: Update the workflow environment variables**

The simplified workflow only requires org and project ID:

```yaml
env:
  PROJECT_ORG: YOUR_ORG_HERE
  PROJECT_ID: YOUR_PROJECT_ID_HERE
```

**Note:** The workflow uses `status-field: Status` and `status-value: Proposed` to set the initial status. No field IDs are required since the `actions/add-to-project` action resolves field names automatically.

## Security: Personal Access Token (PAT)

If using **Method 2**, the workflow requires a GitHub Personal Access Token (PAT) with project permissions.

**Create PAT:**

1. Go to `https://github.com/settings/personal-access-tokens/new` (or **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens** > **Generate new token**)
2. Configure token settings:
   - **Token name:** e.g., "Add to Project Automation"
   - **Expiration:** 90 days (recommended for security)
   - **Repository access:** Select your repository
3. Set permissions:
   - **Repository permissions:**
     - `Issues`: **Read and write** (required for closing issues)
     - `Pull requests`: **Read and write** (required for reading PR linked issues)
     - `Metadata`: Read-only (automatically granted)
   - **Organization permissions:**
     - `Projects`: **Read and write** (required for adding items to projects)
4. Click **Generate token**
5. Copy the token (you won't see it again)

**Add PAT to repository:**

**Option A: Using GitHub CLI (recommended):**
```bash
gh secret set ADD_TO_PROJECT_PAT
# Paste your token when prompted
```

**Option B: Using GitHub web interface:**
1. Go to your repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `ADD_TO_PROJECT_PAT`
4. Value: Paste your token
5. Click **Add secret**

## Troubleshooting

### Workflow not triggering

- Verify the workflow file is in `.github/workflows/` and named with `.yml` extension
- Check the **Actions** tab for error messages
- Ensure the PAT has correct permissions and is not expired

### Items not being added

- Check workflow run logs in the **Actions** tab
- Verify the project URL and organization/project ID are correct
- For Method 1, review the auto-add filter syntax

### Permission errors

- Ensure the PAT has all required permissions:
  - Repository: `Issues` (Read and write), `Pull requests` (Read and write)
  - Organization: `Projects` (Read and write)
- Verify the PAT is stored as `ADD_TO_PROJECT_PAT` in repository secrets
- Check that the workflow uses `secrets.ADD_TO_PROJECT_PAT`, not `secrets.GITHUB_TOKEN`

## Related Commands

- `lol project --create` - Create a new GitHub Projects v2 board
- `lol project --associate <org>/<id>` - Associate an existing project
- `lol project --automation` - Print the workflow template
- `lol project --automation --write <path>` - Write template to file

## References

- [GitHub Projects v2 documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [actions/add-to-project action](https://github.com/actions/add-to-project)
- [GitHub auto-add workflows](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically)
