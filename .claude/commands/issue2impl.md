---
name: issue2impl
description: Complete end-to-end workflow to resolve a GitHub issue with code review cycles
argument-hint: <issue-number>
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git fetch:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(gh repo view:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh issue comment:*), Bash(gh issue create:*), Bash(gh label create:*), Bash(gh api:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh pr comment:*), Bash(make all:*), Bash(make test:*), Bash(ninja:*), Bash(sleep:*), Bash(date:*)
---

## Context

- Repository: !`gh repo view --json nameWithOwner -q '.nameWithOwner'`
- Current branch: !`git branch --show-current`
- Issue number: $1

---

## Phase 1: Input Validation

**Spawn `input-validator` agent (Haiku):**

```
Validate inputs for /issue2impl workflow.
Issue number: $1
Current branch: <from context>
```

The agent performs:
- Issue number format validation
- Branch name contains issue number check
- Issue existence and state verification
- Dependency status check (blocked by, depends on patterns)

**On PASS:** Proceed to Phase 2.

**On WARNING (closed issue):** Ask user for confirmation before proceeding.

**On FAIL:** Display error with suggested fix and stop execution.

---

## Phase 2: Issue Analysis

**Spawn `issue-analyzer` agent:**

```
Analyze GitHub issue #$1 for your project.
```

The agent returns structured analysis including requirements, human comments, relevant files, **estimated scope** (small/medium/large), and **triage assessment** (fast/standard/extended).

**If issue not found or closed:** Display error and stop (or ask user for closed issues).

---

## Phase 2.2: Triage Decision

Based on the `issue-analyzer` triage assessment:

### Triage Tiers

| Tier | Criteria | Workflow Modification |
|------|----------|----------------------|
| `fast` | ANY of: single file, doc-only, <50 lines, `quick-fix` label | Skip Phase 3, 4.1-4.2; simplified Phase 6 |
| `standard` | Default (no fast/extended criteria met) | Full workflow (Phases 3-9) |
| `extended` | ANY of: multi-component, >1500 lines, `complex` label | Add architecture review before Phase 4 |

**Note**: Fast path triggers when ANY single criterion is met. Extended path triggers when ANY of its criteria is met. **Precedence**: If both fast and extended criteria match, extended overrides fast.

### Routing Logic

**If triage tier = `fast` AND confidence = `HIGH`:**
1. Skip Phase 3 (Documentation Review)
2. Skip Phase 4.1-4.2 (Plan Mode)
3. Proceed directly to Phase 5 (Implementation)
4. Use simplified Phase 6 (single review cycle, no rework)

**If triage tier = `fast` AND confidence = `MEDIUM/LOW`:**
1. Ask user to confirm fast-path is appropriate
2. If confirmed: apply fast-path routing
3. If rejected: continue with standard workflow

**If triage tier = `extended`:**
1. Spawn `doc-architect` for architecture review before Phase 4
2. Require user approval before Phase 5
3. Consider splitting into multiple issues

**Otherwise (`standard`):**
1. Continue with full workflow (Phases 3-9)

### User Override

User can always override the triage recommendation at this point by explicitly requesting a different tier.

---

## Phase 3: Documentation Review

**Spawn `doc-architect` agent:**

```
Review documentation completeness for issue #$1.

Issue analysis report: <from Phase 2>
```

The agent works interactively with user, then returns documentation summary and commit hash.

**Skip conditions:** User approval AND (bug fix | trivial <50 lines | no new concepts).

**Checkpoint:** Verify documentation commit exists before proceeding.

---

## Phase 4: Planning and Approval

### 4.1 Enter Plan Mode

Use EnterPlanMode. Plan must include:
- Summary of changes with reference to Phase 3 documentation
- How human comments will be addressed
- Files to create/modify
- Step-by-step approach
- Test strategy
- **Estimated line count**

### 4.2 Size Check

Reference `workflow-reference` skill for size thresholds. If estimated > 1000 lines:
- Identify logical breakpoints
- Plan Phase 1 deliverables
- Note remaining work for potential handoff

### 4.3 User Approval

Present plan. If Yes: proceed. If No/Modify: revise.

### 4.4 Pre-Implementation Build

```bash
make all
```

---

## Phase 5: Implementation

### 5.1 Implement Changes

Follow approved plan. Use Edit/Write tools. Track progress with TodoWrite.

### 5.2 Incremental Build

```bash
make build
```

### 5.3 Size Monitoring

Check **both** committed and uncommitted changes:

```bash
# Committed changes (after interim commits)
git diff origin/main...HEAD --stat | tail -1

# Uncommitted changes (before any commit)
git diff --stat | tail -1
```

**Important**: Before Phase 7, most changes are uncommitted. Use `git diff --stat` during implementation; use `git diff origin/main...HEAD` after interim commits or in Phase 7.

Reference `workflow-reference` skill for thresholds. If Orange/Red zone:
1. Find logical stopping point
2. Proceed to Phase 6 (review current work)
3. Proceed to Phase 7 (commit partial work)
4. Then trigger Phase 5.4 (create handoff for remaining work)

### 5.4 Handoff Trigger (Conditional)

**If size threshold exceeded:**

**Step 5.4.1: Spawn `handoff-generator` agent:**

```
Generate handoff issue for issue #$1.
Branch: <current-branch>
Changes so far: +X/-Y lines
Remaining tasks: <from plan>
```

**Step 5.4.2: Project Board Integration (MANDATORY)**

After `handoff-generator` returns, parse its output to extract issue details, then **spawn `project-manager` agent** (NOTE: project-manager only accepts issues, not PRs):

```
Add issue #<handoff-issue-number> to GitHub Project.

Context:
- Issue number: <from handoff-generator output>
- L1 Component: <from handoff-generator output>
- L2 Subcomponent: <from handoff-generator output, if applicable>
- Priority: <from handoff-generator output>
- Effort: <from handoff-generator output>

Add to appropriate project and update fields.
```

**If project-manager reports permission error:**
- Inform user: "Handoff issue created but could not be added to GitHub Project automatically"
- Suggest: "Run `gh auth refresh -s project` to add project permissions, then retry"
- Provide manual fallback: "Or add manually at: https://github.com/orgs/PolyArch/projects"

---

## Phase 6: Code Review Cycle

### 6.1 Run Code Review

**Spawn `code-reviewer` agent:**

```
Review all changes for issue #$1.
Cycle: X of 3
Previous score: Y/100 (or N/A)
```

Target: Score >= 81.

### 6.2 Process Results

- **>= 81:** Proceed to Phase 7
- **< 81:** Implement fixes, re-check size, re-run 6.1

### 6.3 Review Loop Limit

Maximum 3 cycles. After 3: summarize issues, ask user.

---

## Phase 7: Commit and Push

### 7.0 Pre-Commit Gate

**Spawn `pre-commit-gate` agent:**

```
Verify build and tests pass before commit.
```

**PASS:** Proceed to 7.1. **FAIL:** Return to Phase 6.1.

### 7.1 Stage and Commit

```bash
git status
git diff --stat
git add <files>
```

Follow `/git-commit` and `.claude/rules/git-commit-format.md`.

### 7.2 Rebase on Main

```bash
git fetch origin main
git rebase origin/main
```

If conflicts: resolve, re-run pre-commit gate.

### 7.3 Determine L1/L2 Tags

```bash
gh issue view $1 --json labels --jq '.labels[].name' | grep -E "^L[12]:"
git diff --stat origin/main...HEAD | head -10
```

Reference `workflow-reference` skill for tag inference guide.

### 7.4 Create or Update PR

```bash
gh pr list --head "$(git branch --show-current)" --json number,url --jq '.[0]'
```

**If no PR exists:**
```bash
git push -u origin $(git branch --show-current)
# Title uses clean tags like [CC][Temporal], PR template uses Resolves #N for auto-linking
gh pr create \
  --title "[Component][SubArea][Issue #$1] Description" \
  --body "<PR body>" \
  --assignee "@me"
```

Reference `pr-templates` skill for PR body template (standard or with-handoff).

**If PR exists:**
```bash
git push
```

---

## Phase 8: Remote Review

### 8.0 Wait for PR Processing

```bash
sleep 180
```

Allow GitHub to process the PR, start CI checks, and update status before requesting review.

### 8.1 Trigger Review

```bash
gh pr comment <pr-number> --body "@claude Please review this PR for issue #$1."
```

### 8.2 Wait and Handle

```bash
sleep 180
```

Use `/resolve-pr-comment` logic. Max 2 feedback cycles.

---

## Phase 9: Finalize

### 9.1 Update Related Issues

Run `/update-related-issues $1`.

### 9.2 Final Summary

Reference `pr-templates` skill for summary template (complete or handoff).

---

## Component Integration

| Component | Type | Purpose | Phase | Model |
|-----------|------|---------|-------|-------|
| `input-validator` | Agent | Input validation (issue, branch, dependencies) | 1 | Haiku |
| `issue-analyzer` | Agent | Issue and codebase analysis | 2 | - |
| `doc-architect` | Agent | Interactive documentation brainstorming | 3 | - |
| `code-reviewer` | Agent | Comprehensive skeptical code review with scoring | 6 | - |
| `handoff-generator` | Agent | Create continuation issues | 5.4 | - |
| `project-manager` | Agent | Add issues to GitHub Project board (MANDATORY) | 5.4.2 | - |
| `pre-commit-gate` | Agent | Build and test verification | 7.0 | Haiku |
| `ci-checks` | Skill | CI validation (formatting, special chars, links) | 6 | - |
| `pr-templates` | Skill | PR body and summary templates | 7.4, 9.2 | - |
| `workflow-reference` | Skill | Size thresholds, L1/L2 guide, error handling | 4, 5, 7 | - |
| `/git-commit` | Command | Commit creation | 7.1 | - |
| `/resolve-pr-comment` | Command | PR feedback resolution | 8 | - |
| `/update-related-issues` | Command | Issue chain updates | 9.1 | - |
| `/gen-handoff` | Command | Manual handoff generation | Any | - |

**Project board integration flow:** `handoff-generator` returns issue details → main thread spawns `project-manager`

**Note:** Subagents cannot spawn other subagents. The main thread (this command) is responsible for spawning `project-manager` after `handoff-generator` completes.

---

## Notes

- Use extended thinking for complex decisions
- Follow all rules in `.claude/rules/`
- Track progress with TodoWrite
- **Monitor size throughout** - smaller PRs are easier to review
- **Prefer logical breakpoints** over arbitrary size limits
- Reference `workflow-reference` skill for error handling

## Skill Usage

When the workflow says "Reference `skill-name` skill", use the Skill tool to load that skill's content into context. Skills provide reference tables and templates that are too detailed to include inline.

**When to invoke skills:**
- `workflow-reference`: When you need size thresholds, L1/L2 inference guide, or error handling reference
- `pr-templates`: When creating PR bodies or generating final summaries
- `ci-checks`: When running local CI validation during code review

Skills are invoked on-demand - only load them when you need the specific information they contain.
