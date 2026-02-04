# Tutorial 02: CLI Implementation with `lol impl`

**Read time: 3-5 minutes**

This tutorial covers the complete development cycle from a GitHub issue to merge-ready code using the CLI-first workflow.

## What is `lol impl`?

`lol impl` automates the issue-to-implementation loop using `wt` + `acw` (see `docs/cli/lol.md`). It expects a real GitHub issue and coordinates iterative implementation steps until completion.

### Requirements

- `gh` must be authenticated and able to read the issue
- The issue number must exist in the current repository
- Each iteration needs `.tmp/commit-report-iter-<N>.txt` as the commit message
- Completion requires `.tmp/finalize.txt` (first line is PR title; include `Issue <N> resolved` in the body)
- Prompt templates accept both `{{TOKEN}}` and `{#TOKEN#}` placeholders during rendering

### Workflow Summary

1. Prefetches issue content via `gh issue view` and writes `.tmp/issue-<N>.md`
2. Exits with an error if the fetch fails or the issue content is empty
3. Syncs the issue branch by fetching and rebasing onto the default branch
4. Runs iterative `wt + acw` loops, committing when changes exist
5. Finishes when `.tmp/finalize.txt` is present and contains `Issue <N> resolved`

## Basic Usage

```
lol impl 42
```

Replace `42` with your issue number from Tutorial 01.

## CLI Example (High-Level)

```
User: lol impl 42
Agent: Prefetching issue #42 with gh...
Agent: Syncing branch onto origin/main...
Agent: Iteration 1 (uses .tmp/commit-report-iter-1.txt)
...
Agent: Completion detected in .tmp/finalize.txt
```

## Claude UI Equivalent: `/issue-to-impl` (Milestones)

`/issue-to-impl` is the Claude UI workflow. It uses a milestone-based implementation loop and is documented in `docs/feat/core/issue-to-impl.md`. Use this if you prefer the Claude UI or want the built-in milestone checkpoints.

### What is `/issue-to-impl`?

`/issue-to-impl` orchestrates the full implementation workflow:
1. Creates a development branch
2. Updates documentation
3. Creates test cases
4. Implements the feature incrementally
5. Tracks progress through milestones

### How It Works

The command follows a milestone-based approach:

- **Milestone 1**: Always created automatically (docs + tests, 0/N tests passing)
- **Milestone 2+**: Created every ~800 LOC if tests aren't complete yet
- **Completion**: When all tests pass, implementation is done

This allows large features to span multiple work sessions while maintaining clear context.

### Basic Usage (Claude UI)

```
/issue-to-impl 42
```

### What Happens Automatically

When you run `/issue-to-impl`:

**1. Branch Creation**
- Creates: `issue-42`
- Switches to that branch

**2. Sync with origin/<default>**
- Ensures clean working directory
- Fetches latest from `origin/main` or `origin/master`
- Rebases current branch onto `origin/<default>`
- Stops with guidance if rebase conflicts occur

**3. Documentation (from plan)**
- Creates/updates documentation files
- Adds README files as needed

**4. Plan Caching**
- Extracts "Proposed Solution" from issue body
- Caches to `.tmp/plan-of-issue-{N}.md` for drift awareness
- Plan is included in continuation prompts for easier resumption

**5. Test Cases (from plan)**
- Creates test files
- Implements test cases from Test Strategy

**6. Milestone 1 Commit**
- Commits docs + tests
- Status: 0/N tests passing (expected)
- Uses `--no-verify` (tests not implemented yet)

**7. Implementation Loop**
- Implements code in chunks (~100-200 LOC)
- Runs tests after each chunk
- Tracks total LOC with `git diff --stat`
- Stops at 800 LOC if tests incomplete → creates Milestone 2
- OR continues until all tests pass → completion

### Example: Milestone-Based Flow (Claude UI)

**Step 1: Start implementation**
```
User: /issue-to-impl 42

Agent: Creating branch issue-42...
Agent: Syncing with origin/main...
  - Fetched latest changes
  - Rebased onto origin/main (clean)
Agent: Updating documentation...
  - docs/typescript-support.md created
  - README.md updated
Agent: Creating test cases...
  - tests/test-typescript.sh created (8 test cases)
Agent: Creating Milestone 1...
  - Committed docs + tests (0/8 tests pass)
Agent: Implementing feature...
  [Agent works for ~45 minutes implementing code]
Agent: Milestone 2 created at 820 LOC (3/8 tests pass)

Work remaining: ~380 LOC
Tests failing: 5

Resume with: "Continue from the latest milestone"
```

**Step 2: Resume implementation (next session)**
```
User: Continue from the latest milestone

Agent: Resuming from Milestone 2 for Issue #42
Agent: Test status: 3/8 tests passed
Agent: Continuing implementation...
  [Agent works for ~30 minutes]
Agent: All tests passed (8/8)!

Implementation complete:
- Total LOC: ~1150
- All 8 tests passing

Next step: Review with /code-review
```

## Resuming from Milestones (Claude UI)

If implementation creates a milestone (doesn't complete), resume with natural language:

```
User: Resume from the latest milestone
User: Continue implementation
User: Continue from .tmp/milestones/issue-42-milestone-2.md
```

**How it works**: The system automatically:
1. Detects your current branch (issue-42-*)
2. Finds the latest milestone file in `.tmp/milestones/`
3. Loads context from the milestone (work remaining, test status)
4. Continues implementation from that checkpoint

## Code Review with `/code-review`

Once all tests pass, review your changes:

```
/code-review
```

This runs a comprehensive review checking:
- **Phase 1**: Documentation quality
  - All folders have README.md files
  - Source files have corresponding .md documentation
- **Phase 2**: Code quality and reuse
  - Checks for reinventing existing utilities
  - Validates against project patterns

Review results show one of:
- ✅ **APPROVED** - Ready for merge
- ⚠️  **NEEDS CHANGES** - Minor issues to address
- ❌ **CRITICAL ISSUES** - Must fix before merge

Fix any issues before proceeding.

## Sync with Main Branch

Before creating a PR, sync with the latest changes:

```bash
git checkout main
git pull --rebase origin main
git checkout issue-42
git rebase main
```

If conflicts occur, resolve them manually.

## Creating the Pull Request

Once code review passes and you're synced with main, ask Claude to create a PR:

```
User: Create a pull request for this branch
```

Claude will invoke the `open-pr` skill to create a pull request with:
- Proper title and description
- Summary of changes
- Test plan
- Link to original issue

The PR number is automatically recorded in the session state, enabling the server to include a PR link in completion notifications when running in handsoff mode.

**Note on Commands vs Skills**: Slash commands (like `/code-review`) are pre-defined prompts you invoke directly, while skills (like `open-pr`) are routines implicitly invoked by Claude when you use natural language requests.

## Dry-Run Mode (Claude UI)

Preview the implementation plan before making changes:

```
/issue-to-impl 42 --dry-run
```

**What you see:**
- Branch that would be created
- Files from the plan (documentation, tests, implementation)
- Estimated LOC per step
- Test strategy summary

**What doesn't happen:**
- No branch created
- No files modified
- No commits or milestones
- No PR created

Use dry-run to verify an issue has a complete plan before starting implementation.

## Common Issues

**"No milestone files found"**
- You're on a branch without milestones
- Solution: Use `/issue-to-impl` to start, not manual branch creation

**"Not on development branch"**
- You're on `main` or wrong branch
- Solution: Run `git checkout issue-42` or start with `/issue-to-impl`

**"Rebase conflict detected"**
- Your changes conflict with main branch
- Solution: Manually resolve conflicts, `git add` files, `git rebase --continue`

## Next Steps

- **Tutorial 03**: Learn how to scale up with parallel development (multiple issues at once)
