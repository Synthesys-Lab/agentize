---
name: team-review
description: Multi-perspective code review with inter-reviewer discussion using agent teams
---

# Team Review Command

Multi-perspective code review using Claude Code agent teams. Three specialist reviewers
independently analyze the diff, then challenge each other's findings through direct messaging.
The lead synthesizes a consensus report with findings annotated by challenge outcomes.

Invoke the command: `/team-review`

## Inputs

**From git:**
- Current branch name (for validation and team naming)
- Changed files: `git diff --name-only main...HEAD`
- Full diff: `git diff main...HEAD`

## Outputs

**Terminal output:**
- Consensus review report combining 3 specialist perspectives
- Challenge discussion summary showing which findings survived or were withdrawn
- Overall assessment (APPROVED / NEEDS CHANGES / CRITICAL ISSUES)

## Workflow

### Step 1: Validate Current Branch

```bash
git branch --show-current
```

If on main branch:
```
Error: Cannot review changes on main branch.

Please switch to a development branch (e.g., issue-N-feature-name)
```
Stop execution.

### Step 2: Get Changed Files and Diff

```bash
git diff --name-only main...HEAD
```

If no changes found:
```
No changes detected between main and current branch. Nothing to review.
```
Stop execution.

```bash
git diff main...HEAD
```

Store the branch name as `BRANCH_NAME`, file list as `CHANGED_FILES`, and diff as `FULL_DIFF`.

### Step 3: Create Agent Team

Create an agent team called `review-{BRANCH_NAME}` with 3 specialist teammates.

Each teammate uses **Sonnet** model. Each teammate should only use read-only tools (Read, Grep, Glob).

**Teammate 1 — `correctness`:**
```
You are a correctness reviewer. Focus exclusively on:
- Logic errors and edge cases
- Off-by-one errors and boundary conditions
- Null/undefined handling
- Security vulnerabilities (injection, XSS, auth bypass)
- Error handling completeness
- Race conditions and resource leaks

This maps to review-standard Phase 3 Checks 1, 4, 6 (Indirection, Interface Boundary, Change Impact)
with a correctness lens.

Here are the changed files:
{CHANGED_FILES}

Here is the full diff:
{FULL_DIFF}

Produce findings in this format:
- Location: file:line
  Standard: [Phase X, Check Y — Name]
  Finding: [What's wrong]
  Recommendation: [How to fix]

Number each finding (C1, C2, C3...) for cross-reference during the challenge phase.
When you finish your review, message the lead with your complete findings list.
```

**Teammate 2 — `design`:**
```
You are a design reviewer. Focus exclusively on:
- Unnecessary indirection and abstractions
- Code duplication and reuse opportunities
- Module boundary violations (single responsibility)
- Dependency management (redundant or conflicting deps)
- Project convention adherence
- Architecture quality and SOLID principles

This maps to review-standard Phase 2 Checks 1-5 and Phase 3 Checks 1-3.

Here are the changed files:
{CHANGED_FILES}

Here is the full diff:
{FULL_DIFF}

Produce findings in this format:
- Location: file:line
  Standard: [Phase X, Check Y — Name]
  Finding: [What's wrong]
  Recommendation: [How to fix]

Number each finding (D1, D2, D3...) for cross-reference during the challenge phase.
When you finish your review, message the lead with your complete findings list.
```

**Teammate 3 — `standards`:**
```
You are a standards reviewer. Focus exclusively on:
- Documentation quality (folder READMEs, source .md companions, test docs)
- Documentation and comment content (rationale not history)
- Naming conventions and project patterns
- Type safety and magic numbers
- Commit hygiene (temp files, debug code, inappropriate files)
- Test documentation completeness

This maps to review-standard Phase 1 all checks, Phase 2 Check 6, and Phase 3 Check 5.

Here are the changed files:
{CHANGED_FILES}

Here is the full diff:
{FULL_DIFF}

Produce findings in this format:
- Location: file:line
  Standard: [Phase X, Check Y — Name]
  Finding: [What's wrong]
  Recommendation: [How to fix]

Number each finding (S1, S2, S3...) for cross-reference during the challenge phase.
When you finish your review, message the lead with your complete findings list.
```

### Step 4: Independent Review Phase

Create 3 tasks on the shared task list:

| Task | Assignee | Description |
|------|----------|-------------|
| `review-correctness` | correctness | Review diff for correctness issues (logic, security, edge cases) |
| `review-design` | design | Review diff for design issues (reuse, architecture, modularity) |
| `review-standards` | standards | Review diff for standards compliance (docs, naming, types) |

Wait for all 3 teammates to complete their independent reviews and message the lead with findings.

### Step 5: Cross-Challenge Phase

After all 3 independent reviews are complete, distribute findings to all reviewers for cross-challenge.

Send each reviewer the other two reviewers' findings:
- Send correctness reviewer the design and standards findings
- Send design reviewer the correctness and standards findings
- Send standards reviewer the correctness and design findings

Include this instruction with each message:

```
Review the findings below from the other two reviewers. You MUST challenge at least one
finding you disagree with, believe is exaggerated, or think is incorrect. Send your
challenges directly to the relevant reviewer using this format:

CHALLENGE to [reviewer] on [finding-id]:
Their finding: [summary]
My disagreement: [reason with evidence]
Suggested revision: [alternative assessment or "withdraw this finding"]

After sending challenges, wait for responses. Then defend or withdraw your own findings
when challenged by others. When done, message the lead with your final findings list,
marking each as:
- SURVIVED: finding stands after challenge
- WITHDRAWN: finding retracted (with reason)
- REVISED: finding modified based on challenge
```

Create 3 challenge tasks (dependent on all 3 review tasks):

| Task | Assignee | Depends On | Description |
|------|----------|------------|-------------|
| `challenge-correctness` | correctness | review-correctness, review-design, review-standards | Challenge design and standards findings |
| `challenge-design` | design | review-correctness, review-design, review-standards | Challenge correctness and standards findings |
| `challenge-standards` | standards | review-correctness, review-design, review-standards | Challenge correctness and design findings |

Wait for all 3 challenge tasks to complete.

### Step 6: Synthesize Consensus Report

Collect final findings from all 3 reviewers (with challenge annotations). Produce this report:

```markdown
# Team Code Review Report

**Branch**: {BRANCH_NAME}
**Changed files**: {count} files (+{additions}, -{deletions} lines)
**Review team**: correctness, design, standards (with cross-challenge)

---

## Correctness Review

[Findings from correctness reviewer, each annotated SURVIVED/WITHDRAWN/REVISED]

---

## Design Review

[Findings from design reviewer, each annotated SURVIVED/WITHDRAWN/REVISED]

---

## Standards Review

[Findings from standards reviewer, each annotated SURVIVED/WITHDRAWN/REVISED]

---

## Challenge Discussion Summary

### Challenges Raised
- [Reviewer X challenged Reviewer Y finding Z: reason and outcome]

### Findings Withdrawn After Challenge
- [Finding id]: [Why it was withdrawn]

### Findings Revised After Challenge
- [Finding id]: [Original → Revised]

---

## Overall Assessment

**Status**: [APPROVED / NEEDS CHANGES / CRITICAL ISSUES]

**Consensus findings** (survived cross-challenge):
1. [Actionable recommendation]
2. [Actionable recommendation]

**Merge readiness**: [Ready / Not ready — address N issues first]
```

### Step 7: Clean Up Team

After synthesizing the report, shut down all teammates and clean up the team:

```
Ask all teammates to shut down, then clean up the team.
```

## Comparison with Other Review Commands

| Feature | /team-review | /agent-review | /code-review |
|---------|-------------|---------------|--------------|
| **Execution** | Agent team (3 sessions) | Isolated subagent | Main conversation |
| **Reviewers** | 3 specialists | 1 generalist | 1 generalist |
| **Discussion** | Cross-challenge phase | None | None |
| **Model** | Sonnet (teammates) | Opus | Current model |
| **Best for** | Critical PRs, large diffs | Large diffs | Small diffs |
| **Token cost** | High (3 sessions) | Medium | Low |

## Error Handling

### Agent Teams Not Enabled

If team creation fails because agent teams are not enabled:
```
Error: Agent teams feature is not enabled.

Add to .claude/settings.json:
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```
Stop execution.

### Teammate Failure

If a teammate stops or fails during review:
- Spawn a replacement teammate with the same role and prompt
- If replacement also fails, proceed with available reviews and note the gap in the report

-------------

Follow the workflow above to execute the team-based code review.

$ARGUMENTS
