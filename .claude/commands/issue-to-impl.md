---
name: issue-to-impl
description: Orchestrate full implementation workflow from issue to completion (creates branch, docs, tests, and first milestone)
argument-hint: [issue-number]
---

# Issue-to-Impl Command

Orchestrate the complete implementation workflow from a GitHub issue with an implementation plan to a fully implemented feature.

## Invocation

```
/issue-to-impl [issue-number]
```

**Arguments:**
- `issue-number` (optional): GitHub issue number to implement. If not provided, extracted from conversation context.

## Inputs

**From arguments or conversation:**
- Issue number (required)

**From GitHub issue (via `gh issue view`):**
- Issue title (for branch naming)
- Issue body containing "Proposed Solution" section with:
  - Implementation steps (Docs → Tests → Implementation ordering)
  - Files to modify/create with line ranges
  - LOC estimates per step
  - Test strategy and test cases

**From git:**
- Current branch name (for validation)

## Outputs

**Branch created:**
- New development branch: `issue-{N}-{brief-title}`

**Files created/modified:**
- Documentation files (from plan Step 1)
- Test files (from plan Step 2)
- Implementation files (from plan Steps 3+)
- `.milestones/issue-{N}-milestone-{M}.md` (one or more milestone documents)

**Git commits:**
- Milestone 1 commit (docs + tests, 0/N tests passed)
- Optional: Milestone N commits (incremental progress, M/N tests passed)
- Optional: Delivery commit (all tests passed)

**Terminal output:**
- Success: "Implementation complete: {LOC} LOC, {N}/{N} tests passed"
- Or: "Milestone {M} created at {LOC} LOC ({passed}/{total} tests passed)"

## Skill Integration

### Step 1: Extract Issue Number

If `$ARGUMENTS` provided, use as issue number. Otherwise:
- Search conversation context for patterns: "issue #42", "implement #15", etc.
- If unclear, ask user: "Which issue number should I implement?"

### Step 2: Detect Current Branch

**Check current branch:**
```bash
git branch --show-current
```

**Parse branch name:**
- Extract issue number from pattern `issue-{N}-*` (e.g., `issue-42-add-feature` → 42)
- Compare extracted number to requested issue number from Step 1

**Decision:**
- If branch matches `issue-{N}-*` AND extracted N equals requested issue → Skip Step 3 (branch creation)
- Otherwise → Proceed to Step 3

### Step 3: Create Development Branch

**If Step 2 detected matching branch:**
- Skip `fork-dev-branch` invocation
- Output: "Already on issue-{N} branch: {current-branch}"
- Proceed to Step 4

**Otherwise, invoke:** `fork-dev-branch` skill
**Input:** Issue number from Step 1
**Output:** New branch `issue-{N}-{brief-title}`, switched to that branch

**Skill handles:**
- Fetching issue title via `gh issue view {N} --json title,state`
- Validating issue exists and is open
- Creating branch name from title
- Executing `git checkout -b issue-{N}-{brief-title}`

**Error handling:**
- Issue not found → Stop, display error to user
- Issue closed → Warn user, ask for confirmation
- Branch name mismatch (on issue-M branch, requesting issue N where M ≠ N) → Warn user, ask to confirm or switch

### Step 4: Read Implementation Plan

**Fetch issue body:**
```bash
gh issue view {issue-number} --json body --jq '.body'
```

**Parse body to extract:**
- "Proposed Solution" section (required)
- Implementation steps within that section
- File paths and line ranges for each step
- LOC estimates
- Test strategy details

**Error handling:**
- No "Proposed Solution" section found:
  ```
  Error: Issue #{N} does not have an implementation plan.

  The issue must have a "Proposed Solution" section with:
  - Implementation steps
  - Files to modify/create
  - LOC estimates
  - Test strategy
  ```
  Stop execution.

### Step 5: Update Documentation

**Based on plan:** Identify documentation steps (usually Step 1 or Steps 1-N)

**For each documentation file in plan:**
- Use `Read` tool if file exists (for updates)
- Use `Edit` or `Write` tool to create/modify file
- Follow exact file paths and changes specified in plan

**Track:** Files created/modified for Milestone 1 commit

### Step 6: Create/Update Test Cases

**Based on plan:** Identify test steps (usually Step 2 or Steps N+1-M)

**For each test file in plan:**
- Use `Write` tool to create new test files
- Use `Edit` tool to update existing test files
- Implement test cases as specified in plan's "Test Strategy" section
- Follow project's test patterns (bash scripts with `set -e`)

**Track:** Test files created/modified for Milestone 1 commit

### Step 7: Create Milestone 1

**Stage files with verification:**
```bash
# Stage all changes
git add .

# CRITICAL: Verify staged files before proceeding
git diff --cached --name-only
```

**Pre-commit checklist:**
- [ ] Documentation files staged (e.g., README.md, docs/*.md)
- [ ] Test files staged (e.g., tests/*.sh)
- [ ] NO `.milestones/` files staged (these are local-only checkpoints)

**If `.milestones/` files appear in staged files:**
```bash
# Unstage milestone files immediately
git restore --staged .milestones/
```

**Create milestone document:**
- File: `.milestones/issue-{N}-milestone-1.md`
- Content:
  - Header: Branch, created datetime, LOC = 0, test status = 0/{total}
  - Work Remaining: All implementation steps (non-doc/test steps from plan)
  - Next File Changes: Extracted from first implementation step in plan
  - Test Status: All tests failing (expected, no implementation yet)

**Invoke:** `commit-msg` skill
**Input:**
- Purpose: `milestone`
- Issue number: `{N}`
- Test status: `"0/{total} tests passed"`
**Output:** Milestone commit created with `--no-verify` flag

**Inform user:**
```
Milestone 1 created: Documentation and tests complete (0/{total} tests passed)
Starting automatic implementation loop...
```

### Step 8: Automatic Implementation Loop

**Invoke:** `milestone` skill
**Input:**
- Branch context: current branch (issue-{N}-*)
- Plan reference: GitHub issue #{N}
- Starting LOC count: 0
- Current test status: 0/{total} tests passed

**Milestone skill behavior:**
1. Reads plan from issue
2. Implements code in chunks (100-200 LOC per chunk)
3. Runs tests after each chunk (via `make test` or specific test commands)
4. Tracks cumulative LOC via `git diff --stat`
5. Stops when:
   - **LOC ≥ 800 AND tests incomplete** → Create Milestone {M+1}, inform user
   - **All tests pass** → Signal completion

**Handle milestone skill output:**

**Output A: Milestone created**
```
Milestone {M} created at {LOC} LOC ({passed}/{total} tests passed).

Work remaining: ~{estimated} LOC
Tests failing: {list}
```
Command stops. User must run `/miles2miles` to resume.

**Output B: All tests pass (completion)**
```
All tests passed ({total}/{total})!

Implementation complete:
- Total LOC: ~{LOC}
- All {total} tests passing

Next steps:
1. Create a delivery commit (without [milestone] tag)
2. Review the changes with /code-review
3. Create PR with /open-pr
```

**CRITICAL - Create delivery commit on completion:**

When milestone skill signals completion (all tests pass), invoke `commit-msg` skill:
- Purpose: `delivery` (NOT milestone)
- No `--no-verify` flag (pre-commit hooks run)
- Commit message has NO `[milestone]` tag

**Stage and commit:**
```bash
git add .
git diff --cached --name-only  # Verify no .milestones/ files
```

Then invoke `commit-msg` skill with `purpose=delivery` and appropriate tags based on the changes.

Command completes successfully after delivery commit is created.

**Output C: Critical error**
```
Critical errors detected. Milestone {M} created with error notes.

Errors:
- {error descriptions}
```
Command stops. User must fix errors and run `/miles2miles`.

## Error Handling

### Issue Not Found

```bash
gh issue view {issue-number}
# Exit code: non-zero
```

**Response:**
```
Error: Issue #{issue-number} not found in this repository.

Please provide a valid issue number.
```
Stop execution.

### Issue Closed

```bash
gh issue view {issue-number} --json state
# Output: {"state": "CLOSED"}
```

**Response:**
```
Warning: Issue #{issue-number} is CLOSED.

Continue implementing a closed issue?
```
Wait for user confirmation before proceeding.

### Already on Development Branch

**Scenario 1: Branch matches requested issue**
```bash
git branch --show-current
# Output: issue-42-some-feature
# Requested issue: 42
```

**Response:**
Step 2 detects match. Step 3 skips branch creation and outputs:
```
Already on issue-42 branch: issue-42-some-feature
```
Continue to Step 4.

**Scenario 2: Branch mismatch (on issue-M, requesting issue-N where M ≠ N)**
```bash
git branch --show-current
# Output: issue-45-other-feature
# Requested issue: 42
```

**Response:**
```
Warning: Currently on issue-45 branch, but requested issue 42.

Continue on this branch or switch to main and create new branch?
```
Wait for user choice.

### No Plan in Issue Body

Issue body does not contain "Proposed Solution" section.

**Response:**
```
Error: Issue #{N} does not have an implementation plan.

The issue body must include a "Proposed Solution" section.
```
Stop execution.

### GitHub CLI Not Authenticated

```bash
gh issue view {N}
# Error: authentication required
```

**Response:**
```
Error: GitHub CLI is not authenticated.

Run: gh auth login
```
Stop execution.
