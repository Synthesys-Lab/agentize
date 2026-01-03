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

For more control over automation (e.g., setting custom field values, complex filtering), use the `actions/add-to-project` action.

**Setup steps:**

1. Generate the workflow template:
   ```bash
   lol project --automation
   ```

2. Review the output and save it to your repository:
   ```bash
   lol project --automation --write .github/workflows/add-to-project.yml
   ```

3. Set up the Personal Access Token (see [Security: Personal Access Token (PAT)](#security-personal-access-token-pat) section below)

4. Commit and push:
   ```bash
   git add .github/workflows/add-to-project.yml
   git commit -m "Add GitHub Projects automation workflow"
   git push
   ```

5. Verify the workflow runs on the **Actions** tab

**Template reference:** See [`templates/github/project-auto-add.yml`](../../templates/github/project-auto-add.yml)

**Advantages:**
- Fine-grained control over automation logic
- Can set custom field values (Status, Priority, etc.)
- Supports complex filtering conditions

**Limitations:**
- Requires workflow file maintenance
- Consumes GitHub Actions minutes
- May hit API rate limits on large repos

## Setting Custom Field Values

To automatically set the **Status** field when items are added to your project:

1. Use **Method 2** (GitHub Actions workflow)
2. Edit the workflow file to include field values:
   ```yaml
   - uses: actions/add-to-project@v1.0.2
     with:
       project-url: https://github.com/orgs/${{ env.PROJECT_ORG }}/projects/${{ env.PROJECT_ID }}
       github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
       labeled: bug, enhancement
       label-operator: OR
       # Set Status field to "Proposed" for new issues
       status-field: Status
       status-value: Proposed
   ```

3. See the [`actions/add-to-project` documentation](https://github.com/actions/add-to-project) for all available options

## Security: Personal Access Token (PAT)

If using **Method 2**, the workflow requires a GitHub Personal Access Token (PAT) with project permissions.

**Create PAT:**

1. Go to `https://github.com/settings/personal-access-tokens/new` (or **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens** > **Generate new token**)
2. Configure token settings:
   - **Token name:** e.g., "Add to Project Automation"
   - **Expiration:** 90 days (recommended for security)
   - **Repository access:** Select your repository
3. Set permissions:
   - **Permissions:**
     - `project`: **Read and write** (required for adding items to projects)
     - `metadata`: Read-only (automatically granted)
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

- Ensure the PAT has `project` read/write permissions
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
