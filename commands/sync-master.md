---
name: sync-master
description: Synchronize local main/master branch with upstream (or origin) using rebase
argument_hint: "[PR_NUMBER]"
---

# Sync Master Command

Synchronize your local main or master branch with the latest changes from the upstream repository, then optionally verify a PR's merge status.

Invoke the command: `/sync-master [PR_NUMBER]`

This command will:
1. Check git status for uncommitted changes
2. Detect the default branch (main or master)
3. Checkout to the detected default branch
4. Detect available remotes (upstream or origin)
5. Pull latest changes using `--rebase`
6. If PR number provided, verify the PR is mergeable
7. Report success or failure

## Inputs

- `$ARGUMENTS` (optional): PR number to verify merge status after sync

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

### Step 6: Verify PR Merge Status (if PR number provided)

If `$ARGUMENTS` contains a PR number, query the PR's merge status:

```bash
gh pr view <PR_NUMBER> --json mergeable,mergeStateStatus
```

Parse the JSON response:
- `mergeable`: `MERGEABLE`, `CONFLICTING`, or `UNKNOWN`
- `mergeStateStatus`: `CLEAN`, `DIRTY`, `BLOCKED`, `BEHIND`, etc.

### Step 7: Report Results

If sync successful and no PR number provided:

```
Successfully synchronized <detected-branch> branch with <detected-remote>/<detected-branch>
```

If sync successful and PR is mergeable (`mergeable` = `MERGEABLE` and `mergeStateStatus` = `CLEAN`):

```
Successfully synchronized <detected-branch> branch with <detected-remote>/<detected-branch>

PR #<PR_NUMBER> is mergeable.
```

If sync successful but PR has conflicts (`mergeable` = `CONFLICTING`):

```
Successfully synchronized <detected-branch> branch with <detected-remote>/<detected-branch>

PR #<PR_NUMBER> has merge conflicts. Please rebase your PR branch on <detected-branch>.
```

If sync successful but PR is blocked or behind (`mergeStateStatus` = `BLOCKED` or `BEHIND`):

```
Successfully synchronized <detected-branch> branch with <detected-remote>/<detected-branch>

PR #<PR_NUMBER> status: <mergeStateStatus>
Please check the PR for required checks or updates.
```

If rebase conflicts occur, inform the user:

```
Error: Rebase conflict detected

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
- Rebase conflicts → User resolves manually
- Remote not configured → Git will error naturally
- PR not found → `gh` will error naturally
