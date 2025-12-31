# Tutorial 02: Issue to Implementation

**Read time: 3-5 minutes**

This tutorial covers the complete development cycle from a GitHub issue to merge-ready code.

## What is `/issue-to-impl`?

`/issue-to-impl` orchestrates the full implementation workflow:
1. Creates a development branch
2. Updates documentation
3. Creates test cases
4. Implements the feature incrementally
5. Tracks progress through milestones

## How It Works

The command follows a milestone-based approach:

- **Milestone 1**: Always created automatically (docs + tests, 0/N tests passing)
- **Milestone 2+**: Created every ~800 LOC if tests aren't complete yet
- **Completion**: When all tests pass, implementation is done

This allows large features to span multiple work sessions while maintaining clear context.

## Basic Usage

```
/issue-to-impl 42
```

Replace `42` with your issue number from Tutorial 01.

## What Happens Automatically

When you run `/issue-to-impl`:

**1. Branch Creation**
- Creates: `issue-42-brief-description`
- Switches to that branch

**2. Sync with origin/<default>**
- Ensures clean working directory
- Fetches latest from `origin/main` or `origin/master`
- Rebases current branch onto `origin/<default>`
- Stops with guidance if rebase conflicts occur

**3. Documentation (from plan)**
- Creates/updates documentation files
- Adds README files as needed

**4. Test Cases (from plan)**
- Creates test files
- Implements test cases from Test Strategy

**5. Milestone 1 Commit**
- Commits docs + tests
- Status: 0/N tests passing (expected)
- Uses `--no-verify` (tests not implemented yet)

**6. Implementation Loop**
- Implements code in chunks (~100-200 LOC)
- Runs tests after each chunk
- Tracks total LOC with `git diff --stat`
- Stops at 800 LOC if tests incomplete → creates Milestone 2
- OR continues until all tests pass → completion

## Example: Complete Flow

**Step 1: Start implementation**
```
User: /issue-to-impl 42

Agent: Creating branch issue-42-add-typescript-support...
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

Run /miles2miles to continue in your next session.
```

**Step 2: Resume implementation (next session)**
```
User: /miles2miles

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

## Resuming with `/miles2miles`

If implementation creates a milestone (doesn't complete), resume with:

```
/miles2miles
```

**How it works**: `/miles2miles` takes a milestone document as input - without a milestone document, there are no "miles" to continue to the next "miles". The command automatically:
1. Detects your current branch (issue-42-*)
2. Finds the latest milestone file in `.milestones/`
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

## Sync and Merge with `/sync-master`

Before creating a PR, sync with the latest changes:

```
/sync-master
```

This command:
1. Checks for uncommitted changes (must commit first)
2. Switches to `main` (or `master`)
3. Pulls latest changes with `--rebase` from `upstream` (or `origin`)
4. Reports success or conflicts

After syncing, switch back to your branch and merge:

```bash
git checkout issue-42-add-typescript-support
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

**Note on Commands vs Skills**: Slash commands (like `/code-review`, `/sync-master`) are pre-defined prompts you invoke directly, while skills (like `open-pr`) are routines implicitly invoked by Claude when you use natural language requests.

## Complete Workflow Example

Here's the full cycle for issue #42:

```
# 1. Start implementation
/issue-to-impl 42
[... Milestone 2 created at 820 LOC ...]

# 2. Resume (next session)
/miles2miles
[... All tests pass! ...]

# 3. Review code
/code-review
[... ✅ APPROVED ...]

# 4. Sync with main
/sync-master
[... Successfully synchronized ...]

# 5. Rebase your branch
git checkout issue-42-add-typescript-support
git rebase main

# 6. Create PR
User: Create a pull request
[... Claude invokes open-pr skill ...]
[... PR created: https://github.com/your-repo/pull/123 ...]

# 7. Merge (after approval)
[Merge via GitHub UI or gh pr merge]
```

## Understanding Milestones

Milestones are checkpoint documents in `.milestones/`:

```
.milestones/
├── issue-42-milestone-1.md
├── issue-42-milestone-2.md
└── issue-42-milestone-3.md
```

Each milestone contains:
- **Header**: branch, datetime, LOC, test status
- **Work Remaining**: incomplete implementation steps
- **Next File Changes**: files to modify next
- **Test Status**: passed and failed tests with details

See `docs/milestone-workflow.md` for complete documentation.

## Tips

1. **Let it run**: `/issue-to-impl` works automatically - let it complete or reach a milestone
2. **Review milestones**: Check `.milestones/` files to understand progress
3. **Always sync**: Run `/sync-master` before creating PRs to avoid conflicts
4. **Fix review issues**: Address `/code-review` findings before merging
5. **Clean working directory**: Commit changes before `/sync-master`, `/miles2miles`, or `/issue-to-impl` (all require clean working tree for rebasing)

## Next Steps

- **Tutorial 03**: Learn how to scale up with parallel development (multiple issues at once)

## Common Issues

**"No milestone files found"**
- You're on a branch without milestones
- Solution: Use `/issue-to-impl` to start, not manual branch creation

**"Not on development branch"**
- You're on `main` or wrong branch
- Solution: Run `git checkout issue-42-brief-title` or start with `/issue-to-impl`

**"Rebase conflict detected"**
- Your changes conflict with main branch
- Solution: Manually resolve conflicts, `git add` files, `git rebase --continue`
