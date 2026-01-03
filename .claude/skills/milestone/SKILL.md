---
name: milestone
description: Drive implementation forward incrementally with automatic progress tracking, LOC monitoring, and milestone checkpoint creation
---

# Milestone Skill

This skill is a core component for implementing large features incrementally, providing transparent context through LOC tracking, test execution, and milestone checkpoint creation when the 800 LOC threshold is reached without completion.

## Skill Purpose

The milestone skill enables AI agents to implement large features step-by-step in manageable increments. It:

- **Implements incrementally**: Works in chunks of 100-200 LOC per iteration
- **Tracks progress**: Monitors total LOC count across the session
- **Runs tests continuously**: Executes tests after each implementation chunk
- **Creates checkpoints**: Generates milestone documents at 800 LOC threshold
- **Signals completion**: Returns success when all tests pass

This skill is the core implementation driver used by `/issue-to-impl` and `/miles2miles` commands.

## Philosophy

- **Incremental progress over big bang**: Small, testable chunks beat large rewrites
  - Provide unobvious technical insights and design decisions you made during this chunk of implementation
- **Transparent checkpoints**: Milestone documents provide clear progress visibility
- **LOC-based pacing**: Use lines of code (not time) to determine when to checkpoint
- **Partially complete work:** You are allowed to have some test failures at milestones, which particularly means you **are REQUIRED** to run a thorough test suite after each chunk of implementation, and before creating a milestone.
  - The milestone document will record the status of all the tests, including passed and failed tests.
    - **Example**
      - **Before:** 5/8 tests Passed
      - **After:** 6/8 tests Passed
      - **Next Steps:** Fix remaining 2 tests in next milestone
  - You should dynamically adjust our plan with the whole plan and the current status of milestone.
    - Did you incrementally finish some tests that were failing in the previous milestone?
    - Did you find some new edge cases that require new tests to be written?
    - Did you unexpectedly break some test cases that were passing before? Is it related or unrelated to the current implementation plan?

---

## Inputs

The milestone skill takes the following inputs (extracted from context):

1. **Current branch context**
   - Branch name (extracted from: `git branch --show-current`)
   - Must be a development branch matching pattern: `issue-{N}-{brief-title}`
   - Issue number extracted from branch name

2. **Plan reference**
   - **First invocation**: Read plan from GitHub issue using `gh issue view {N}`
   - **Resume invocation**: Read from latest milestone document in `.milestones/issue-{N}-milestone-*.md`
   - Plan contains: implementation steps, file changes, LOC estimates, test strategy

3. **Starting LOC count** (optional, for resume scenarios)
   - When resuming from a milestone, start from the LOC count in that milestone
   - When starting fresh (first milestone), start from 0

4. **Current test status** (determined by running tests)
   - You do not need to pass all the tests before creating a milestone, but you **MUST** run the tests after each implementation chunk to determine current status.
   - You should provide a summary of the test results in the milestone document, including:
     - Test passed as expected by this chunk of implementation
     - Test failed as expected by this chunk of implementation
     - Test unexpectedly broken by this chunk of implementation
     - What is planned to be worked on in the immediately next milestone

---

## LOC Tracking Mechanism

The AI agent **MUST** track LOC count accurately to determine when to create milestones.

### How to Track LOC

Use `git diff --stat` to measure code changes:

```bash
# Get stats for uncommitted changes
git diff --stat

# Example output:
#  .claude/skills/milestone/SKILL.md | 156 ++++++++++++++++++++++++++++++++++++++
#  docs/milestone-workflow.md         | 187 ++++++++++++++++++++++++++++++++++++++++++
#  2 files changed, 343 insertions(+)
```

### LOC Calculation

Extract the total LOC count from the summary line:
- Pattern: `X files changed, Y insertions(+), Z deletions(-)`
- **Total LOC = Y (insertions) + Z (deletions)**
- Example: `343 insertions(+), 25 deletions(-)` → **Total LOC = 368**

### Accumulation Across Chunks

**CRITICAL**: Track cumulative LOC across multiple implementation chunks:

```python
# Pseudocode for LOC tracking
cumulative_loc = starting_loc  # From milestone or 0
while not all_tests_pass:
    implement_next_chunk()  # Implement 100-200 LOC
    current_chunk_loc = get_git_diff_stat()
    cumulative_loc += current_chunk_loc

    run_tests()
    test_status = parse_test_results()

    # Check stopping condition
    if cumulative_loc >= 800 and not all_tests_pass:
        create_milestone(cumulative_loc, test_status)
        stop_and_inform_user()
        break

    if all_tests_pass:
        signal_completion()
        break
```

### Stop Threshold

- **Stop when**: `cumulative_loc >= 800` AND tests are not all passing
- **Continue if**: `cumulative_loc < 800` OR all tests pass (nearing completion)
- **Exception**: If very close to completion (> 750 LOC and > 90% tests pass), continue to finish

---

## Implementation Loop

The AI agent **MUST** follow this implementation loop:

### 1. Read Plan or Milestone Context

**First invocation** (from issue):
```bash
gh issue view {issue-number} --json body --jq '.body'
```
- Extract "Proposed Solution" section (contains the plan)
- Identify implementation steps from the plan
- Note files to modify/create with LOC estimates

**Resume invocation** (from milestone):
```bash
# Find latest milestone
ls -1 .milestones/issue-{N}-milestone-*.md | sort -V | tail -n 1
```
- Read the latest milestone file
- Extract "Work Remaining" section
- Extract "Next File Changes" section
- Extract "Test Status" to understand current state

### 2. Determine Next Work

From the plan or milestone:
- Identify the next incomplete implementation step
- Determine which files need changes
- Understand what to implement in the next chunk
- Provide unobvious technical insights and design decisions you made for this chunk of implementation

**Chunk size guideline**: Aim for 100-200 LOC per chunk
- If a step is > 200 LOC, break it into substeps
- Implement one substep per iteration

### 3. Implement the Chunk

Implement the next logical piece of functionality:

```
Agent: Implementing [description of what's being implemented]

[Uses Edit/Write tools to modify code]

Agent: Changes made:
- path/to/file1.py: Added feature X logic (~120 LOC)
- path/to/file2.py: Updated helper functions (~45 LOC)
```

**Best practices:**
- Focus on one logical unit per chunk
- Write clean, readable code
- Follow existing code patterns and conventions
- Add comments where logic is not self-evident

### 4. Check LOC Count

After implementing the chunk:

```bash
git diff --stat
```

Parse the output and add to cumulative count:
```
Agent: Chunk complete: ~165 LOC added
Agent: Cumulative LOC: 615 (starting from 450)
```

### 5. Run Tests

Execute the test suite after each chunk:

```bash
# If project has Makefile with test target
make test

# Or run specific test files mentioned in the plan
bash tests/test-feature.sh

# Or run all tests
bash tests/test-all.sh
```

**Capture test output** for parsing:
```
Agent: Running tests...
[test output]
Agent: Test results: 5/8 tests passed
```

### 6. Parse Test Results

Extract test status from output:

**Passed tests** (look for success markers):
- `✓` symbol
- "passed" keyword
- "OK" status
- Exit code 0 for individual tests

**Failed tests** (look for failure markers):
- `✗` symbol
- "failed" keyword
- "ERROR" or "FAILED" status
- Exit code non-zero

**Example parsing:**
```
Test output:
  ✓ Test 1: Feature initialization
  ✓ Test 2: Config loading
  ✗ Test 3: Edge case handling
  ✓ Test 4: Error recovery
  ✗ Test 5: Integration test
  ✓ Test 6: Cleanup

Parsed status:
  Passed: Tests 1, 2, 4, 6 (4 tests)
  Failed: Tests 3, 5 (2 tests)
  Total: 6 tests
  Percentage: 67% (4/6)
```

### 7. Check Stopping Conditions

After running tests, evaluate:

**Condition A: All tests pass**
```
if test_pass_percentage == 100%:
    signal_completion()
    return SUCCESS
```
→ Implementation is complete, ready for PR

**Condition B: LOC threshold reached without completion**
```
if cumulative_loc >= 800 and test_pass_percentage < 100%:
    create_milestone()
    inform_user_to_run_miles2miles()
    return MILESTONE_CREATED
```
→ Checkpoint needed, stop for user intervention

**Condition C: Continue implementation**
```
if cumulative_loc < 800 and test_pass_percentage < 100%:
    continue_loop()  # Go back to step 2
```
→ Keep implementing next chunk

**Condition D: Near completion exception**
```
if cumulative_loc >= 750 and cumulative_loc < 850 and test_pass_percentage >= 90%:
    continue_loop()  # Push to finish
```
→ Close enough to completion, don't create milestone

---

## Milestone Creation Logic

When the stop threshold is reached (Condition B), create a milestone document.

### Step 1: Determine Milestone Number

```bash
# Count existing milestones for this issue
ls -1 .milestones/issue-{N}-milestone-*.md 2>/dev/null | wc -l
```

Milestone number = count + 1

### Step 2: Extract Work Remaining

From the original plan (in issue), identify which steps are not yet complete:

**Original plan:**
```
Step 1: Update documentation (150 LOC) ✓ DONE
Step 2: Create tests (100 LOC) ✓ DONE
Step 3: Implement core logic (250 LOC) ← IN PROGRESS (partial)
Step 4: Add edge case handling (150 LOC) ← NOT STARTED
Step 5: Integration (100 LOC) ← NOT STARTED
```

**Work Remaining section:**
```markdown
## Work Remaining

- Step 3: Implement core logic (Estimated: ~100 LOC remaining)
  - File: src/core.py - Complete validation logic
  - File: src/utils.py - Add helper methods
- Step 4: Add edge case handling (Estimated: 150 LOC)
  - File: src/core.py - Handle edge cases
  - File: tests/test_edge_cases.sh - Verify edge case handling
- Step 5: Integration (Estimated: 100 LOC)
  - File: src/main.py - Integrate with existing system
```

### Step 3: Estimate Next File Changes

Based on current implementation state and remaining work:

```markdown
## Next File Changes (Estimated LOC for Next Milestone)

- `src/core.py`: Complete validation logic and add edge case handling (~180 LOC)
- `src/utils.py`: Add helper methods for validation (~45 LOC)
- `tests/test_edge_cases.sh`: Verify edge case handling (~60 LOC)

**Total estimated for next milestone:** ~285 LOC
```

### Step 4: Document Test Status

List all tests with their current status:

```markdown
## Test Status

**Passed Tests:**
- test-agentize-modes.sh: All 6 tests passed
- test-c-sdk.sh: All tests passed
- test-feature.sh: 4/6 tests passed
  - Test 1: Feature initialization
  - Test 2: Config loading
  - Test 4: Error recovery
  - Test 6: Cleanup

**Not Passed Tests:**
- test-feature.sh: 2/6 tests failing
  - Test 3: Edge case handling (FAILED)
    - Error: Validation logic incomplete
  - Test 5: Integration test (FAILED)
    - Error: Integration code not yet implemented
```

### Step 5: Write Milestone Document

Create the file `.milestones/issue-{N}-milestone-{M}.md`:

```markdown
# Milestone {M} for Issue #{N}

**Branch:** issue-{N}-{brief-title}
**Created:** {current-datetime}
**LOC Implemented:** ~{cumulative_loc} lines
**Test Status:** {passed}/{total} tests passed

[Work Remaining section from Step 2]

[Next File Changes section from Step 3]

[Test Status section from Step 4]
```

**CRITICAL: Local-Only Checkpoint Files**

Milestone documents in `.milestones/` are LOCAL CHECKPOINT FILES ONLY:

- **DO NOT** stage these files: `git add .milestones/` is FORBIDDEN
- **DO NOT** force-add these files: `git add -f .milestones/*` is FORBIDDEN
- **DO NOT** commit these files under any circumstances
- These files are automatically excluded by `.gitignore` when using `git add .`

**Why `.milestones/` files must remain local:**
1. They are working notes for resuming implementation between sessions
2. They contain partial progress states not suitable for repository history
3. `.gitignore` already excludes them to prevent accidental staging
4. Only completed implementation code/tests/docs should be committed

**Verification:** Before creating any commit, verify staged files:
```bash
git diff --cached --name-only
```
If you see any `.milestones/` files listed, **STOP** and unstage them:
```bash
git restore --staged .milestones/
```

### Step 6: Create Milestone Commit

Use the `commit-msg` skill with milestone flag:

**CRITICAL - Pre-Commit Verification:**

Before invoking `commit-msg`, verify what will be staged:
```bash
# Stage implementation changes only
git add .

# Verify staged files (milestone files should NOT appear)
git diff --cached --name-only
```

**Requirements:**
- **MUST stage**: Implementation code, tests, documentation
- **MUST NOT stage**: `.milestones/issue-{N}-milestone-{M}.md` (local checkpoint only)
- If `.milestones/` files appear in `git diff --cached`, unstage them immediately:
  ```bash
  git restore --staged .milestones/
  ```

**Invoke commit-msg skill with:**
- Purpose: milestone
- Staged files: all implementation changes (code, tests, documentation)
  - EXCLUDE: `.milestones/issue-{N}-milestone-{M}.md` (keep this local only)
- Issue number: {N}
- Test status: "{passed}/{total} tests passed"

The commit-msg skill will:
- Create commit message with `[milestone][tag]` prefix
- Include test status in message
- Use `git commit --no-verify` to bypass pre-commit hooks
- Reference the issue number

**Example commit message:**
```
[milestone][agent.skill]: Milestone 2 for issue #42

.claude/skills/milestone/SKILL.md: Implement LOC tracking and test parsing logic
docs/milestone-workflow.md: Add workflow documentation

Milestone progress: 820 LOC implemented, 5/8 tests passed.
Tests failing: edge case handling, integration tests.

NOTE: Milestone document (.milestones/issue-42-milestone-2.md) is NOT committed - it remains local for resumption.
```

### Step 7: Inform User

Display message to user:

```
Milestone {M} created at {cumulative_loc} LOC ({passed}/{total} tests passed).

Work remaining: ~{estimated_remaining_loc} LOC
```

**Next Steps:**

To resume implementation from this checkpoint, use natural language:
```
User: Resume from the latest milestone
User: Continue implementation
User: Continue from .milestones/issue-{N}-milestone-{M}.md
```

The system will auto-detect the latest milestone on the current branch.

---

## Completion Signal

When all tests pass (Condition A), signal completion:

```
All tests passed ({total}/{total})!

Implementation complete:
- Total LOC: ~{cumulative_loc}
- All {total} tests passing

Next steps:
1. Create a delivery commit (without [milestone] tag):
   - Stage all changes: git add .
   - Create commit with purpose=delivery (runs pre-commit hooks)
   - All tests must pass for commit to succeed
2. Review and create PR with /pull-request --open
   - Or use /code-review then /open-pr for manual workflow
```

**CRITICAL - Completion requires a delivery commit:**

When all tests pass, **DO NOT create a milestone**. Instead:

1. **Stage changes for delivery commit:**
   ```bash
   git add .
   git diff --cached --name-only  # Verify staged files
   ```

2. **Create delivery commit using commit-msg skill:**
   - Purpose: `delivery` (NOT milestone)
   - No `--no-verify` flag (normal pre-commit hooks run)
   - All tests must pass for commit to succeed
   - Commit message has NO `[milestone]` tag

3. **Delivery commit distinguishes completed work from checkpoints:**
   - Milestone commits = intermediate checkpoints with incomplete tests
   - Delivery commits = completed work with all tests passing
   - Only delivery commits should be merged to main branch

**Example delivery commit message:**
```
[feat][agent.command]: Add TypeScript support to build system

src/build.ts: Implement TypeScript compilation pipeline
tests/test-typescript.sh: Add TypeScript validation tests

All 8 tests passing. Ready for code review.
```

---

## Error Handling

### Not on Development Branch

```bash
git branch --show-current
```

If branch does not match pattern `issue-{N}-*`:

```
Error: Not on a development branch.

Current branch: {branch-name}

You must be on a development branch (issue-{N}-{brief-title}) to use the milestone skill.

Please run /issue-to-impl to start implementation on a proper development branch.
```

Stop execution.

### No Plan Found

If unable to find plan in issue or milestone:

```
Error: No implementation plan found.

Checked:
- GitHub issue #{N}: No "Proposed Solution" section
- Milestone files: No .milestones/issue-{N}-milestone-*.md found

Please ensure:
1. The issue has a plan
2. You're running /issue-to-impl to start implementation

Cannot proceed without a plan.
```

Stop execution.

### Tests Fail Critically (Syntax Errors)

If tests fail to run due to syntax errors or import errors:

```bash
# Test output indicates syntax error
make test
# Output: SyntaxError: invalid syntax...
```

Create milestone with error notes:

```markdown
## Test Status

**Critical Errors:**
- Syntax error in src/core.py:45
- Import error: module 'utils' not found

**Test Execution:** Failed to run tests due to critical errors.

**Next Steps:**
1. Fix syntax errors
2. Resolve import issues
3. Resume with /miles2miles
```

Then stop and inform user:

```
Critical errors detected. Milestone {M} created with error notes.

Errors:
- Syntax error in src/core.py:45
- Import error: module 'utils' not found

Please fix these errors and resume with: "Continue from the latest milestone"
```

### Milestone File Creation Fails

If unable to create milestone file:

```
Error: Failed to create milestone file at .milestones/issue-{N}-milestone-{M}.md

Possible causes:
- .milestones/ directory does not exist
- Permission issues

Please ensure .milestones/ directory exists and is writable.
```

Try to create the directory:
```bash
mkdir -p .milestones
```

Then retry creating the milestone file.

If still fails, stop and report error to user.

---

## Examples

### Example 1: First Milestone (Fresh Start)

**Context:** User runs `/issue-to-impl 42` for a feature with 8 test cases.

**Agent behavior:**

```
Agent: Starting implementation for issue #42...
Agent: Reading plan from issue...
Agent: Plan loaded: 5 implementation steps, estimated 950 LOC total

Agent: Step 1 complete: Documentation updated
Agent: Step 2 complete: Test cases created (8 tests)
Agent: Creating Milestone 1...
Agent: Milestone 1 created (0/8 tests passed)

Agent: Starting implementation loop...
Agent: Implementing Step 3: Core logic...
  [implements chunk 1: ~180 LOC]
Agent: Cumulative LOC: 180
Agent: Running tests... 2/8 tests passed
Agent: Implementing Step 3: Validation logic...
  [implements chunk 2: ~150 LOC]
Agent: Cumulative LOC: 330
Agent: Running tests... 3/8 tests passed
Agent: Implementing Step 4: Edge cases...
  [implements chunk 3: ~200 LOC]
Agent: Cumulative LOC: 530
Agent: Running tests... 5/8 tests passed
Agent: Implementing Step 4: Error handling...
  [implements chunk 4: ~180 LOC]
Agent: Cumulative LOC: 710
Agent: Running tests... 6/8 tests passed
Agent: Implementing Step 5: Integration...
  [implements chunk 5: ~140 LOC]
Agent: Cumulative LOC: 850
Agent: Running tests... 6/8 tests passed
Agent: LOC threshold reached (850 >= 800), creating Milestone 2...

Milestone 2 created at 850 LOC (6/8 tests passed).

Work remaining: ~100 LOC (Step 5 partial completion)
Tests failing: Integration test, Performance test

Resume with: "Continue from the latest milestone"
```

### Example 2: Resume from Milestone

**Context:** User resumes after Milestone 2 was created.

**Agent behavior:**

```
Agent: Finding latest milestone for current branch...
Agent: Found: .milestones/issue-42-milestone-2.md
Agent: Loading context...

Resuming from Milestone 2 for Issue #42:
- LOC implemented: 850
- Test status: 6/8 tests passed
- Work remaining: ~100 LOC

Agent: Reading work remaining from milestone...
Agent: Next work: Complete Step 5 integration

Agent: Implementing integration logic...
  [implements chunk: ~85 LOC]
Agent: Cumulative LOC: 935 (850 + 85)
Agent: Running tests... 7/8 tests passed
Agent: Implementing performance optimization...
  [implements chunk: ~45 LOC]
Agent: Cumulative LOC: 980 (935 + 45)
Agent: Running tests... 8/8 tests passed!

All tests passed (8/8)!

Implementation complete:
- Total LOC: ~980
- All 8 tests passing
- Ready for PR creation

Next steps:
1. Review the changes
2. Use /open-pr to create a pull request
```

### Example 3: Near Completion Exception

**Context:** At 780 LOC with 7/8 tests passing (87.5%).

**Agent behavior:**

```
Agent: Cumulative LOC: 780
Agent: Running tests... 7/8 tests passed (87.5%)

Agent: Near completion detected:
- LOC: 780 (close to threshold)
- Tests: 87.5% passing
- Estimated remaining: ~50 LOC

Agent: Continuing to push for completion instead of creating milestone...

Agent: Implementing final test fix...
  [implements chunk: ~35 LOC]
Agent: Cumulative LOC: 815
Agent: Running tests... 8/8 tests passed!

All tests passed (8/8)!

Implementation complete:
- Total LOC: ~815
- All 8 tests passing
- Ready for PR creation
```

**Note:** Even though cumulative LOC exceeded 800, the agent continued because:
- Started at 780 (close to threshold)
- Test pass percentage was high (87.5%)
- Estimated remaining work was minimal (~50 LOC)
- Better to complete than create another milestone for trivial remaining work

---

## Next Steps

If milestone checkpoint is created it should hint the user to resume later:
```
Resume with: "Continue from the latest milestone"
```

If milestone successfully delivers its goal, it should direct user to opening a PR:
```
Next step: /pull-request --open
```
where `\pull-request` already have `/code-review` hooked, and will finally open the PR after review approval.

If milestone fails due to errors that cannot be fixed by AI alone, it should inform the user
the phenomenon and suggest manual intervention to fix the issues before resuming, by creating
a comment right below the Github issue.
