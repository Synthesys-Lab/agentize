---
name: resolve-review
description: Fetch unresolved PR review threads and apply fixes with user confirmation
---

# Resolve Review Command

Automates resolving unresolved PR review comments by fetching threads via GitHub's GraphQL API, applying AI-driven code modifications with user confirmation, running tests with bounded retry, and pushing changes with proper `[review]` tag commit formatting. Validates branch context and fails fast on mismatch (automation-friendly).

Invoke the skill: /resolve-review <pr-no>

## Inputs

**From arguments:**
- `<pr-no>` (required): The pull request number to process

**From GitHub (via `gh` CLI):**
- PR metadata: state, headRefName
- Repository: owner, name
- Review threads via `scripts/gh-graphql.sh review-threads`

**From git:**
- Current branch name (for validation against PR head)

## Outputs

**Terminal output:**
- List of unresolved review threads with file/line context
- Proposed changes for each thread (with confirmation prompts)
- Git diff summary before test execution
- Test results (pass/fail with retry status)
- Commit and push status

**Git commits:**
- Commit with `[review]` tag first, following `docs/git-msg-tags.md` conventions

## Workflow Steps

### Step 1: Validate PR Number

Check that `<pr-no>` is provided and numeric:

```bash
# Validate argument exists and is numeric
if [ -z "$PR_NO" ] || ! [[ "$PR_NO" =~ ^[0-9]+$ ]]; then
  echo "Error: Please provide a valid PR number"
  echo "Usage: /resolve-review <pr-no>"
  exit 1
fi
```

### Step 2: Fetch PR Metadata and Repo Info

```bash
# Get PR details
gh pr view "$PR_NO" --json state,headRefName,headRepository

# Get repo owner/name
gh repo view --json owner,name
```

**Error handling:**
- PR not found → Stop with error message
- PR closed/merged → Warn user, ask for confirmation

### Step 3: Validate Working Branch

Check that the current branch matches the PR head branch. On mismatch, abort immediately and leave a failure comment on the PR (fail-fast for automation compatibility):

```bash
CURRENT_BRANCH=$(git branch --show-current)
PR_HEAD=$(gh pr view "$PR_NO" --json headRefName --jq '.headRefName')

if [ "$CURRENT_BRANCH" != "$PR_HEAD" ]; then
  # Leave failure comment on PR for visibility
  gh pr comment "$PR_NO" --body "⚠️ /resolve-review aborted: Current branch ($CURRENT_BRANCH) does not match PR head ($PR_HEAD). Please ensure the correct worktree is active."

  echo "Error: Branch mismatch - current ($CURRENT_BRANCH) != PR head ($PR_HEAD)"
  echo "Failure comment left on PR #$PR_NO"
  exit 1
fi
```

This fail-fast behavior ensures compatibility with server-managed worktree workflows that require non-interactive execution.

### Step 4: Fetch Unresolved Review Threads

```bash
# Get repo info
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

# Fetch review threads
THREADS=$(scripts/gh-graphql.sh review-threads "$OWNER" "$REPO" "$PR_NO")

# Filter to unresolved and non-outdated threads
UNRESOLVED=$(echo "$THREADS" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false)]')
```

**Error handling:**
- GraphQL error → Display error, stop execution
- `pageInfo.hasNextPage` is true → Warn about pagination limitation

### Step 5: Check for Unresolved Threads

```bash
COUNT=$(echo "$UNRESOLVED" | jq 'length')

if [ "$COUNT" -eq 0 ]; then
  echo "No unresolved review threads found."
  echo "All review comments have been addressed."
  exit 0
fi

echo "Found $COUNT unresolved review thread(s)"
```

### Step 6: Process Each Thread

For each unresolved thread:

1. **Display thread context:**
   ```
   ─────────────────────────────────────────
   Thread 1/3: src/utils/parser.py:42
   ─────────────────────────────────────────
   @reviewer1 commented:
   > Consider adding error handling for empty input

   File context (lines 40-45):
   ```

2. **Read file context:**
   Use the Read tool to show surrounding code context at the specified path and line range.

3. **Propose changes:**
   Analyze the review comment and propose code modifications.

4. **Request confirmation:**
   ```
   Apply these changes? [y/n/s(skip)]
   ```

5. **Apply changes (if confirmed):**
   Use Edit tool to apply the proposed modifications.

### Step 7: Show Diff Summary and Confirm Tests

After processing all threads:

```bash
git diff --stat
```

Display the summary and ask:
```
Run tests (make test)? [y/n]
```

### Step 8: Run Tests with Bounded Retry

```bash
MAX_ATTEMPTS=2
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  echo "Running tests (attempt $ATTEMPT/$MAX_ATTEMPTS)..."

  if make test; then
    echo "All tests passed!"
    break
  else
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
      echo "Tests failed. Attempting to fix..."
      # Allow one fix attempt
      ATTEMPT=$((ATTEMPT + 1))
    else
      echo "Tests still failing after $MAX_ATTEMPTS attempts."
      echo "Please review the failures manually."
      # Ask user whether to proceed anyway or abort
    fi
  fi
done
```

### Step 9: Stage and Commit

```bash
git add .
```

Invoke `/git-commit` command, ensuring the commit message:
- Uses `[review]` tag first per `docs/git-msg-tags.md` conventions
- Describes which review comments were addressed

Example commit message format:
```
[review][bugfix] Address PR review feedback

- Add error handling for empty input in parser
- Add test case for special characters
```

### Step 10: Push Changes

```bash
git push
```

Display summary:
```
✓ Resolved 2 review threads
✓ Tests passing
✓ Changes pushed to origin/$BRANCH
```

## Error Handling

### PR Not Found

```
Error: PR #123 not found in this repository.

Verify the PR number and try again.
```

### No Unresolved Threads

```
No unresolved review threads found.
All review comments have been addressed.
```

### Branch Mismatch

When the current branch doesn't match the PR head, the command aborts immediately and leaves a failure comment on the PR:

**Terminal output:**
```
Error: Branch mismatch - current (main) != PR head (feature-branch)
Failure comment left on PR #123
```

**PR comment:**
```
⚠️ /resolve-review aborted: Current branch (main) does not match PR head (feature-branch). Please ensure the correct worktree is active.
```

This fail-fast behavior supports automation workflows where interactive prompts are not compatible.

### GraphQL Pagination Warning

If `pageInfo.hasNextPage` is true:
```
Warning: PR has more than 100 review threads.
Only the first 100 threads were fetched.
Consider running the command again after resolving these.
```

### Test Failures After Retry

```
Tests still failing after 2 attempts.

Failing tests:
- tests/cli/test-parser.sh

Options:
1. Review and fix manually
2. Commit anyway (not recommended)
3. Abort changes
```
