---
name: pull-request
description: Review code changes and optionally create a pull request with --open flag
argument-hint: [--open]
---

# Pull Request Command

Streamline the review and PR creation workflow by running code review and optionally creating a pull request.

## Invocation

```
/pull-request [--open]
```

**Arguments:**
- `--open` (optional): After review passes, create PR immediately. Without this flag, command runs review and stops.

## Inputs

**From git:**
- Current branch name (for PR creation)
- Changes since main branch (for review)

**From GitHub (via gh CLI):**
- Repository information
- Branch tracking status

## Outputs

**Without --open flag:**
- Code review results displayed
- Next-step guidance provided
- NO pull request created

**With --open flag:**
- Code review results displayed
- Pull request created (if review passes)
- PR URL returned

## Skill Integration

### Step 1: Parse Arguments

Check if `$ARGUMENTS` contains `--open` flag:

```bash
if [[ "$ARGUMENTS" == *"--open"* ]]; then
    CREATE_PR=true
else
    CREATE_PR=false
fi
```

### Step 2: Run Code Review

**Invoke:** `/code-review` command

This runs the standard code review process:
- Analyzes changes from current HEAD to main branch
- Checks code quality, documentation, and test coverage
- Returns review findings

**Capture review output:**
- If review finds critical issues: errors or blockers
- If review finds minor issues: warnings or suggestions
- If review passes: no critical issues

### Step 3: Handle Review Results

**Case A: Review has critical issues**

```
Code review found critical issues:

{list of critical issues}

Please fix these issues before creating a PR.
```

Stop execution. DO NOT proceed to PR creation regardless of `--open` flag.

**Case B: Review has minor issues**

```
Code review complete with suggestions:

{list of suggestions}

You may proceed with PR creation, but consider addressing these first.
```

- If `--open` flag present: Ask user to confirm PR creation
- If no `--open` flag: Stop with next-step guidance (see Step 4)

**Case C: Review passes**

```
Code review passed!

{optional: positive feedback}
```

- If `--open` flag present: Proceed to Step 5 (create PR)
- If no `--open` flag: Stop with next-step guidance (see Step 4)

### Step 4: Provide Next-Step Guidance (No --open flag)

When command runs without `--open` flag and review completes:

```
Code review complete.

Next steps:
1. Review the findings above
2. Fix any issues if needed
3. Run /pull-request --open to create PR
   OR
   Run /open-pr directly
```

Stop execution. User decides when to create PR.

### Step 5: Create Pull Request (--open flag)

Only reached when:
- `--open` flag was provided
- Review passed or user confirmed despite warnings

**Invoke:** `open-pr` skill

The skill will:
- Create PR using `gh pr create`
- Generate PR title and description
- Return PR URL

**Output PR URL:**
```
Pull request created successfully!

PR: {URL}

Next steps:
1. Review the PR on GitHub
2. Address any CI failures
3. Request reviews from team members
```

Command completes successfully.

## Error Handling

### Not on Development Branch

```bash
git branch --show-current
# Output: main or master
```

**Response:**
```
Error: Cannot create PR from main branch.

You must be on a development branch to create a pull request.
```

Stop execution.

### No Changes to Review

```bash
git diff main...HEAD
# Output: (empty)
```

**Response:**
```
Error: No changes to review.

Your branch has no commits ahead of main.
```

Stop execution.

### GitHub CLI Not Authenticated

```bash
gh auth status
# Exit code: non-zero
```

**Response:**
```
Error: GitHub CLI is not authenticated.

Run: gh auth login
```

Stop execution (only affects PR creation if `--open` flag present).

### Review Command Fails

If `/code-review` command itself fails (not review findings, but execution error):

**Response:**
```
Error: Code review failed to execute.

{error details}

Cannot proceed with PR creation.
```

Stop execution.

### PR Creation Fails

If `open-pr` skill fails when `--open` flag is present:

**Response:**
```
Error: Failed to create pull request.

{error details from open-pr skill}

Your changes have been reviewed and are ready for PR.
You can try creating the PR manually with:
gh pr create
```

Stop execution. Review was successful but PR creation failed.

## Usage Examples

### Example 1: Review Only (Default)

```
User: /pull-request

Agent: Running code review...
Agent: [review results]
Agent: Code review complete.

Next steps:
1. Review the findings above
2. Fix any issues if needed
3. Run /pull-request --open to create PR
```

### Example 2: Review + Create PR

```
User: /pull-request --open

Agent: Running code review...
Agent: [review results]
Agent: Code review passed!
Agent: Creating pull request...
Agent: Pull request created successfully!

PR: https://github.com/org/repo/pull/123
```

### Example 3: Review Finds Issues

```
User: /pull-request --open

Agent: Running code review...
Agent: Code review found critical issues:
  - Missing test coverage for new feature
  - Undocumented public API changes

Please fix these issues before creating a PR.
```

## Design Notes

**Why not auto-create PR on every completion?**
- Gives users control over when PR is created
- Allows fixing review findings first
- Supports workflow flexibility (some users prefer manual PR creation)

**Why have two modes (with/without --open)?**
- Default behavior is safe (review only, no side effects)
- `--open` flag is explicit opt-in for PR creation
- Avoids approval-waiting patterns in command execution

**Integration with existing commands:**
- Uses existing `/code-review` command (no duplication)
- Uses existing `open-pr` skill (no duplication)
- Thin wrapper that adds convenience without complexity
