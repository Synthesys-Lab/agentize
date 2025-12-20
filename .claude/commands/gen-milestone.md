---
name: gen-milestone
description: Generate a milestone GitHub issue for the next agent
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(gh issue view:*), Bash(gh issue create:*), Bash(gh issue comment:*), Bash(gh label create:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(date:*)
---

## Context

- Current branch: !`git branch --show-current`
- Repository: !`gh repo view --json nameWithOwner -q '.nameWithOwner'`

---

## Task: Generate Milestone Issue

Generate a GitHub issue to enable the next agent to continue work efficiently.

GitHub issues are the standard output format for milestones because they provide:
- Tracking in GitHub project board
- Linking to parent issues and PRs
- Searchable and filterable
- Support for labels and categorization
- Comments for updates and discussion

---

## Milestone Issue Creation

### Step 1: Gather Current State

Run these commands to gather current state:

1. Get current branch:
```bash
git branch --show-current
```

2. Get change statistics:
```bash
git diff origin/main...HEAD --stat
```

3. Get recent commits:
```bash
git log --oneline -10 origin/main..HEAD
```

4. Check if build directory exists by verifying the path

### Step 2: Identify Parent Issue

Check if current work is related to an issue:

1. Extract issue number from the branch name (look for numeric patterns)
2. If issue number found, verify it exists:
```bash
gh issue view <issue-number> --json number,title,state
```

3. Check for existing PR:
```bash
gh pr view --json number,title,body
```

### Step 3: Analyze Remaining Work

Review conversation history and identify:
- What was the original goal?
- What has been completed?
- What remains to be done?
- What technical insights were gained?
- What are the recommended next steps?

### Step 4: Create Milestone Issue

First, ensure required labels exist (these may already exist):
```bash
gh label create "milestone" --description "Work continuation point" --color "7057ff"
```
```bash
gh label create "continuation" --description "Continues previous work" --color "0e8a16"
```

**Issue Title Format** (follow project's 3-tag system):
```
[Component][SubArea][Issue #XX] <what-needs-to-be-done-next>
```

Or:
```
[Component][SubArea][PR #YY] <what-needs-to-be-done-next>
```

Where:
- `Component` - The primary tool (e.g., `CC`, `SIM`, `MAPPER`)
- `SubArea` - The feature area (e.g., `Temporal`, `CMSIS`)
- `[Issue #XX]` or `[PR #YY]` - Reference to parent issue/PR

**Examples**:
- `[CC][Temporal][Issue #123] Implement remaining pattern matchers`
- `[SIM][CMSIS][PR #456] Complete test coverage`
- `[HWGEN][Issue #789] Add hardware generation`

**Issue Body Template**:

```markdown
## Milestone Summary

**Parent Issue**: #<issue-number> (if applicable)
**Branch**: `<branch-name>`
**Created**: <YYYY-MM-DD HH:MM>

---

## Current Status

### Progress Metrics
- Lines changed: +X/-Y
- Files modified: N
- Build status: PASSING/FAILING
- Tests: X passing, Y failing

### Completed Work
- [x] Task 1 (commit: `abc1234`)
- [x] Task 2 (commit: `def5678`)

### Latest Commits
```
<output of git log --oneline -5>
```

---

## Remaining Tasks

### Priority 1: <Task Name>
**Difficulty**: LOW/MEDIUM/HIGH/COMPLEX
**Objective**: What needs to be accomplished
**Target files**:
- `/path/to/file.cpp:lines` - What to modify
**Expected outcome**: What tests should pass or behavior should work
**Implementation hints**: Patterns to follow, entry points

### Priority 2: <Task Name>
...

---

## Technical Insights

### Key Discovery: <Topic>
- **Finding**: What was learned
- **Implication**: How it affects implementation
- **Location**: `file:line` where this applies

---

## Code Navigation

| Purpose | File | Lines | Notes |
|---------|------|-------|-------|
| Main implementation | `/path/to/file` | X-Y | Description |
| Tests | `/tests/file` | X-Y | Test patterns |

---

## Quick Start

```bash
# Setup
git checkout <branch>
git pull origin <branch>

# Verify state
make all
git status

# Run relevant tests
llvm-lit -v build/tests/<relevant-path>
```

---

## Direct Milestone Command

> **Copy this to start the next session:**

<Clear, self-contained instruction with:
- Specific file paths and line ranges
- Imperative verb (Implement, Fix, Add, Update)
- Definition of "done" (tests to pass, behavior to achieve)
- Priority level
- Key constraints>

---

_Labels: `milestone`, `continuation`, `L1:<component>`, `L2:<area>`_
```

### Step 5: Determine Component/SubArea and Source Tags

Before creating the issue, determine the appropriate tags and labels:

```bash
# Check parent issue labels (if parent issue exists)
gh issue view <parent-issue> --json labels --jq '.labels[].name' | grep -E "^L[12]:"

# Or infer from files modified
git diff --stat origin/main...HEAD | head -20
```

**1. Identify Source Tag**:
- If continuing from an issue: Use `[Issue #XX]`
- If continuing from a PR: Use `[PR #YY]`
- Extract from branch name or parent context

**2. Component Tag Inference** (title tags → labels):
- `lib/dsa/Dialect/` or `tools/dsa-cc/` → `[CC]` (label: `L1:CC`)
- `lib/dsa/Simulation/` or `tools/dsa-sim/` → `[SIM]` (label: `L1:SIM`)
- `lib/dsa/Mapper/` or `tools/dsa-mapper/` → `[MAPPER]` (label: `L1:MAPPER`)
- `lib/dsa/HWGen/` or `tools/dsa-hwgen/` → `[HWGEN]` (label: `L1:HWGEN`)
- `tests/` → `[TEST]` (label: `L1:TEST`)

**3. SubArea Tag Guidance**:
- Use parent issue's L2 tag if present
- Infer from content (e.g., memory-related → `[Memory]`, temporal-related → `[Temporal]`)
- If unclear, omit SubArea tag (e.g., `[CC][Issue #123] Description`)

### Step 6: Create the Issue

Use `gh issue create` with the proper title format and labels:

```bash
# Title uses source tag [Issue #XX] or [PR #YY] instead of generic [Milestone]
gh issue create \
  --title "[<component>][<subarea>][<source>] <description>" \
  --body "<issue-body>" \
  --label "milestone,continuation,L1:<component>,L2:<subarea>" \
  --assignee "@me"
```

Where `<source>` is `Issue #XX` or `PR #YY`.

The body should follow the template above and be passed using a HEREDOC.

### Step 7: Add to GitHub Project (MANDATORY)

**CRITICAL**: Every issue created MUST be added to the GitHub Project board. This step is NOT optional.

**Spawn the `project-manager` agent** to add the issue to the appropriate GitHub Project (NOTE: project-manager only accepts issues, not PRs):

```
Add issue #<new-issue-number> to GitHub Project.

Context:
- Issue number: <new-issue-number>
- L1 Component: <L1 tag from issue title>
- L2 Subcomponent: <L2 tag from issue title, if applicable>
- Priority: <infer from parent issue or set to Medium>
- Effort: <estimate based on remaining work>

Add to the appropriate project and update fields.
```

**If project-manager reports permission error:**
- Inform user: "Issue created but could not be added to GitHub Project automatically"
- Suggest: "Run `gh auth refresh -s project` to add project permissions, then retry"
- Provide manual fallback: "Or add manually at: https://github.com/orgs/PolyArch/projects"

**DO NOT skip this step.** The project board is the primary tracking mechanism for all DSA Stack issues.

### Step 8: Link to Parent (if applicable)

If there's a parent issue, add a comment linking to the new milestone issue:
```bash
gh issue comment <parent-issue> --body "Milestone created: #<new-issue-number>"
```

### Step 9: Report Results

```
## Milestone Created

**Issue**: #<number>
**URL**: <url>
**Title**: [X][Y][Issue #Z] <description> (labels: L1:X, L2:Y)
**Source**: Issue #Z or PR #Z
**Project**: <project-name> (if added successfully)

### Summary
- Parent: #<parent-issue> (if any)
- Completed: X tasks
- Remaining: Y tasks

### Project Fields
- Status: Todo
- L1 Component: <value>
- L2 Subcomponent: <value> (if applicable)
- Priority: <value>
- Effort: <value>

### To Continue
Copy this to the next session:
> <direct milestone command>
```

---

## Validation Checklist

Before finalizing, verify:
- [ ] Current status metrics are accurate
- [ ] All remaining tasks are clearly defined
- [ ] Code locations include file paths and line numbers
- [ ] Direct milestone command is self-contained
- [ ] Direct milestone command uses imperative verbs
- [ ] No fabricated time estimates (use ranges or "TBD")
- [ ] Quick start commands are runnable

---

## Integration

This command can be invoked:
- Manually by user: `/gen-milestone`
- By `/issue2impl` when size threshold exceeded
- At end of session when work is incomplete

This command spawns:
- `project-manager` agent to add created issues to GitHub Project and update fields

For automatic milestone during `/issue2impl`, use the `milestone-generator` agent which follows the same structure but is optimized for integration with the issue workflow.
