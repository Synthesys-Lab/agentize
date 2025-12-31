---
name: sync-master
description: Synchronize local main/master branch with upstream (or origin) using rebase
---

# Sync Master Command

Synchronize your local main or master branch with the latest changes from the upstream repository, and rebase your feature branch onto the updated main.

Invoke the command: `/sync-master`

This command will:
1. Check git status for uncommitted changes
2. Save the current branch name (if not on main/master)
3. Detect the default branch (main or master)
4. Checkout to the detected default branch
5. Detect available remotes (upstream or origin)
6. Pull latest changes using `--rebase`
7. Rebase the saved feature branch onto updated main (if applicable)
8. Report success or failure

## Workflow Steps

When this command is invoked, follow these steps:

### Step 1: Check Working Tree Status

Check if there are uncommitted changes:

```bash
git status --porcelain
```

If the output is non-empty, inform the user:

```
Error: Cannot sync - you have uncommitted changes

Please commit or stash your changes before syncing.
```

Stop execution.

### Step 1.5: Save Current Branch

Save the current branch name for later rebase:

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

Inform the user:

```
Saving current branch: <current-branch>
```

This allows the command to return to the feature branch and rebase it after syncing main.

### Step 2: Detect Default Branch

Check which default branch exists in the repository:

```bash
git rev-parse --verify main 2>/dev/null || git rev-parse --verify master 2>/dev/null
```

- If `main` exists, use `main`
- Otherwise, if `master` exists, use `master`
- If neither exists, inform the user:

```
Error: Neither 'main' nor 'master' branch found in this repository
```

Stop execution.

### Step 3: Checkout Default Branch

Switch to the detected default branch:

```bash
git checkout <detected-branch>
```

Inform the user:

```
Checking out <detected-branch> branch...
```

### Step 4: Detect Remote

Check which remote to use (prefer upstream, fallback to origin):

```bash
git remote | grep -q "^upstream$"
```

- If `upstream` exists, use `upstream`
- Otherwise, use `origin`

If using fallback, inform the user:

```
upstream remote not found, using origin...
```

### Step 5: Pull with Rebase

Pull the latest changes from the detected remote:

```bash
git pull --rebase <detected-remote> <detected-branch>
```

Inform the user:

```
Pulling latest changes from <detected-remote> with rebase...
```

### Step 5.5: Rebase Feature Branch

If the current branch was saved and is different from the detected default branch, rebase it onto the updated main:

```bash
if [ "$CURRENT_BRANCH" != "$DETECTED_BRANCH" ]; then
    git checkout "$CURRENT_BRANCH"
    git rebase "$DETECTED_BRANCH"
fi
```

Inform the user:

```
Rebasing <current-branch> onto <detected-branch>...
```

If no feature branch was saved (already on main/master), skip this step.

### Step 6: Report Main Sync Results

If successful:

```
Successfully synchronized <detected-branch> branch with <detected-remote>/<detected-branch>
```

If rebase conflicts occur on main, inform the user:

```
Error: Rebase conflict detected on <detected-branch>

Please resolve conflicts manually:
1. Fix conflicts in the affected files
2. Run: git add <resolved-files>
3. Run: git rebase --continue

Or abort the rebase with: git rebase --abort
```

Stop execution and let the user handle conflicts.

### Step 7: Report Feature Branch Rebase Results

If a feature branch was rebased:

If successful:

```
Rebased <current-branch> onto <detected-branch>
```

If conflicts occur during feature branch rebase, inform the user:

```
Error: Rebase conflict detected on <current-branch>

This conflict occurred while rebasing your feature branch onto the updated <detected-branch>.

Please resolve conflicts manually:
1. Fix conflicts in the affected files
2. Run: git add <resolved-files>
3. Run: git rebase --continue

Or abort the rebase with: git rebase --abort
```

Stop execution and let the user handle conflicts.

## Error Handling

Following the project's philosophy, assume git tools are available and the repository is properly initialized. Cast errors to users for resolution.

Common error scenarios:
- Uncommitted changes → User must commit or stash
- Branch not found → Inform user
- Rebase conflicts on main → User resolves manually, then continue or abort
- Rebase conflicts on feature branch → User resolves manually on feature branch
- Remote not configured → Git will error naturally
