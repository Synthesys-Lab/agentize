---
name: feat2issue
description: Transform design ideas into actionable GitHub issues through interactive brainstorming, research, and planning
argument-hint: <idea-text-or-file-path>
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(gh repo view:*), Bash(gh issue create:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(git branch:*), Bash(git checkout:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(date:*), Bash(ls:*), Bash(mkdir:*), WebSearch, WebFetch
---

## Context

- Repository: !`gh repo view --json nameWithOwner -q '.nameWithOwner'`
- Current branch: !`git branch --show-current`
- Raw input: $ARGUMENTS

---

## Overview

This command transforms design ideas into actionable GitHub issues through a 7-phase workflow:

0. **Input Validation**: Parse and validate input (text or file path)
1. **Interactive Brainstorming**: Critical discussion to refine the idea
2. **Issue Research**: Find related existing GitHub issues
3. **Documentation Research**: Analyze current docs state
4. **Planning**: Plan documentation changes and implementation issues
5. **Implementation**: Create docs PR and implementation issues
6. **Cleanup**: Update related issues

---

## Phase 0: Input Validation

**Spawn `feat2issue-validator` agent (Haiku):**

```
Validate inputs for /feat2issue workflow.
Raw input: $ARGUMENTS
```

The agent performs:
- Empty input check
- Input type detection (text vs file path)
- File existence and content validation (if file path)

**On PASS:** Extract IDEA_CONTENT from agent output and proceed to Phase 1.

**On FAIL:** Display error and stop execution.

---

## Phase 1: Interactive Brainstorming (Three-Agent Chain)

Phase 1 uses a chain of three specialized agents to ensure thorough design exploration and validation:

```
User -> idea-creative-proposer -> idea-critical-checker -> idea-comprehensive-analyzer -> User
```

### Step 1.1: Creative Proposal Generation

**Spawn `idea-creative-proposer` agent:**

```
Generate creative design proposals for the following idea:

---
$IDEA_CONTENT
---

Knowledge bases available:
- docs/ - Project documentation
- externals/docs/ - External dependencies documentation

Your role:
1. Understand the idea deeply and identify the core problem
2. Research prior art (codebase and web)
3. Generate at least 3 distinct creative alternatives
4. Explore unconventional approaches
5. Provide structured proposals for review

Output: PROPOSER_RESULT with proposals for critical review
```

**Checkpoint**: Wait for agent to complete. Store output as PROPOSER_OUTPUT.

### Step 1.2: Critical Review

**Spawn `idea-critical-checker` agent:**

```
Critically evaluate the following design proposals:

---
PROPOSER OUTPUT:
$PROPOSER_OUTPUT
---

ORIGINAL IDEA:
$IDEA_CONTENT
---

Knowledge bases available:
- docs/ - Project documentation
- externals/docs/ - External dependencies documentation

Your role:
1. Verify all research claims and factual statements
2. Identify logical fallacies and flawed reasoning
3. Challenge unstated assumptions
4. Classify issues by severity (critical/significant/minor)
5. Assess viability of each proposal

Output: CHECKER_RESULT with rigorous critique
```

**Checkpoint**: Wait for agent to complete. Store output as CHECKER_OUTPUT.

### Step 1.3: Comprehensive Synthesis

**Spawn `idea-comprehensive-analyzer` agent:**

```
Synthesize the creative proposals and critical review into a final recommendation:

---
PROPOSER OUTPUT:
$PROPOSER_OUTPUT
---

CHECKER OUTPUT:
$CHECKER_OUTPUT
---

ORIGINAL IDEA:
$IDEA_CONTENT
---

Knowledge bases available:
- docs/ - Project documentation
- externals/docs/ - External dependencies documentation

Your role:
1. Independently verify disputed claims between proposer and checker
2. Evaluate both sides fairly as a neutral arbiter
3. Resolve conflicts and find synthesis opportunities
4. Provide clear recommendation with rationale
5. If design confirmed, create draft document

Output: ANALYZER_RESULT with final recommendation
```

**Checkpoint**: Wait for agent to complete.

### Step 1.4: User Decision Point

**If agent returns "DESIGN_CONFIRMED":**
- Store DRAFT_PATH from agent output
- Display summary to user
- Proceed to Phase 2

**If agent returns "REVISION_NEEDED":**
- Display blocking issues and questions to user
- Wait for user feedback
- Incorporate feedback into IDEA_CONTENT as `IDEA_CONTENT + USER_FEEDBACK`
- **Restart the full chain** (Steps 1.1 → 1.2 → 1.3) with augmented context
- Repeat Step 1.4

**If agent returns "DESIGN_ABANDONED":**
- Display: "Brainstorming concluded. Design was deemed unviable after comprehensive analysis. No artifacts created."
- Stop execution

---

## Phase 2: GitHub Issue Research

**Spawn `issue-researcher` agent:**

```
Research existing GitHub issues related to this design topic.

Draft document: $DRAFT_PATH

Search for:
1. Issues with similar objectives
2. Issues that might conflict
3. Issues that could be superseded
4. Related PRs and their outcomes

Return structured analysis of issue landscape.
```

**Output**: ISSUE_STATUS_REPORT containing:
- List of related issues with state and relevance
- Recommendations per issue (update/close/create new)
- Conflict analysis

---

## Phase 3: Documentation Research

**Spawn `doc-researcher` agent:**

```
Analyze documentation state for this design topic.

Draft document: $DRAFT_PATH
Issue status: <from Phase 2>

Analyze:
1. Current docs/ structure relevant to topic
2. Existing content needing updates
3. Documentation gaps
4. External best practices (via WebSearch)

Return documentation state analysis with recommendations.
```

**Output**: DOC_STATUS_REPORT containing:
- Related existing documentation
- Outdated content needing updates
- Gaps requiring new documentation
- Recommended locations (draft/architecture/roadmap)

---

## Phase 4: Planning

### 4.1 Synthesize Research

Combine outputs from Phases 1-3:
- Refined design from brainstorming (DRAFT_PATH)
- Issue landscape (ISSUE_STATUS_REPORT)
- Documentation state (DOC_STATUS_REPORT)

### 4.2 Enter Plan Mode

Use EnterPlanMode. The plan must have TWO parts:

**Part 1: Documentation Changes**
- What files to create/update in `docs/architecture/` or `docs/roadmap/`
- The draft document to include in commit
- GitHub issue for the documentation work
- Branch name: `issue-<N>-doc-<topic>`

**Part 2: Implementation Issues**
- Issues to CREATE (with L1/L2 tags, acceptance criteria)
- Issues to UPDATE (what changes, why)
- Issues to CLOSE (rationale, check no active PRs)
- Dependencies between issues

**Important constraints for implementation issues:**
- Issues describe REQUIREMENTS and DESIGN, not implementation code
- API signatures and key structures are acceptable
- No large code blocks
- Reference finalized documentation
- Each issue should be actionable by `/issue2impl`

### 4.3 User Approval

Present complete plan. Wait for explicit approval.

If user rejects or modifies: Revise plan accordingly.

---

## Phase 5: Implementation

### 5.1 Documentation PR (Part 1)

#### 5.1.1 Create Documentation Issue

```bash
# Get timestamp
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Create issue for documentation work (title uses [DOCS], label uses L1:DOCS)
gh issue create \
  --title "[DOCS] Design documentation for <topic>" \
  --body "<issue-body-from-plan>" \
  --label "L1:DOCS,documentation" \
  --assignee "@me"
```

Store issue number as DOC_ISSUE_NUMBER.

#### 5.1.1a Add Documentation Issue to Project Board (MANDATORY)

**Spawn `project-manager` agent** for the documentation issue (NOTE: project-manager only accepts issues, not PRs):

```
Add issue #$DOC_ISSUE_NUMBER to GitHub Project.

Context:
- Issue number: $DOC_ISSUE_NUMBER
- L1 Component: DOCS
- Priority: Medium
- Effort: <from plan, default S (1-4h)>

Add to appropriate project and update fields.
```

**If project-manager reports permission error:**
- Inform user: "Documentation issue created but could not be added to GitHub Project automatically"
- Suggest: "Run `gh auth refresh -s project` to add project permissions, then retry"
- Provide manual fallback: "Or add manually at: https://github.com/orgs/PolyArch/projects"

#### 5.1.2 Create Branch and Apply Changes

```bash
# Create branch
git checkout -b "issue-$DOC_ISSUE_NUMBER-doc-<topic>"

# Apply documentation changes from plan:
# - Create/update docs/architecture/*.md
# - Create/update docs/roadmap/*.md
# - The draft at docs/draft/<topic>-<timestamp>.md should already exist

git status
```

#### 5.1.3 Commit and Create PR

Follow `/git-commit` and `.claude/rules/git-commit-format.md`:

```bash
git add docs/
git commit -m "[docs] Add design documentation for <topic>

[docs] /docs/draft/<file>.md : Brainstorming record and design decisions
[docs] /docs/architecture/<file>.md : Finalized design specification"

git push -u origin "issue-$DOC_ISSUE_NUMBER-doc-<topic>"
```

Create PR (title uses clean tags, body includes Resolves #N for auto-linking):
```bash
gh pr create \
  --title "[DOCS][Issue #$DOC_ISSUE_NUMBER] <topic> design documentation" \
  --body "<PR-body>" \
  --assignee "@me"
```

Store PR number as DOC_PR_NUMBER.

#### 5.1.4 Leave PR for Review

**IMPORTANT**: Do NOT auto-merge documentation PRs. Architectural documentation requires human review.

```bash
# Request review (optional)
gh pr edit $DOC_PR_NUMBER --add-reviewer <team-or-user>

# Display PR status
echo "Documentation PR #$DOC_PR_NUMBER created and ready for review."
echo "Implementation issues will reference this PR."
```

Proceed to create implementation issues. The docs PR can be merged after review.

### 5.2 Implementation Issues (Part 2)

**Spawn `issue-creator` agent:**

```
Create implementation issues based on approved plan.

Plan Part 2: <implementation-issues-from-plan>
Documentation PR: #$DOC_PR_NUMBER
Documentation reference: <paths-to-finalized-docs>

For each issue to CREATE:
1. Read issue-templates skill content for body format
2. Apply L1/L2 labels
3. Reference documentation
4. Set dependencies

For each issue to UPDATE:
1. Edit body or add comment as appropriate
2. Update labels if needed

For each issue to CLOSE:
1. Verify no active PRs
2. Close with explanation
3. Reference superseding issues

Return: List of created issue numbers for project board integration.
```

**Output**: List of created/updated/closed issue numbers.

### 5.3 Project Board Integration (MANDATORY)

**CRITICAL**: Every issue created MUST be added to the GitHub Project board. This step is NOT optional.

**NOTE**: Subagents cannot spawn other subagents. The main thread handles project board integration.

For each issue created by issue-creator, **spawn `project-manager` agent** (NOTE: project-manager only accepts issues, not PRs):

```
Add issue #<issue-number> to GitHub Project.

Context:
- Issue number: <from issue-creator output>
- L1 Component: <L1 tag>
- L2 Subcomponent: <L2 tag, if applicable>
- Priority: <from plan>
- Effort: <estimate from plan>

Add to appropriate project and update fields.
```

**If project-manager reports permission error:**
- Inform user: "Issue created but could not be added to GitHub Project automatically"
- Suggest: "Run `gh auth refresh -s project` to add project permissions, then retry"
- Provide manual fallback: "Or add manually at: https://github.com/orgs/PolyArch/projects"

**DO NOT skip this step.** The project board is the primary tracking mechanism for all DSA Stack issues.

---

## Phase 6: Cleanup

### 6.1 Update Related Issues

For each implementation issue created, run the update chain:

Run `/update-related-issues <first-implementation-issue>`.

This will:
- Update related issues in the graph
- Add cross-references
- Update statuses as appropriate

### 6.2 Final Summary

```markdown
## /feat2issue Complete

### Input
- **Original idea**: <brief summary>
- **Draft document**: $DRAFT_PATH

### Documentation
- **Issue**: #$DOC_ISSUE_NUMBER
- **PR**: #$DOC_PR_NUMBER ($STATUS)
- **Files created/updated**:
  - docs/architecture/<file>.md
  - docs/roadmap/<file>.md (if any)

### Implementation Issues Created
| Issue | Title | Labels | Dependencies |
|-------|-------|--------|--------------|
| #XXX | [X][Y] Title | L1:X, L2:Y | None |
| #XXX | [X][Y] Title | L1:X, L2:Y | #XXX |

### Issues Updated
| Issue | Change |
|-------|--------|
| #XXX | Updated body with new design |
| #XXX | Added comment referencing new work |

### Issues Closed
| Issue | Reason |
|-------|--------|
| #XXX | Superseded by #YYY |

### Next Steps

To implement these issues, use:
```
/issue2impl <issue-number>
```

Start with issues that have no dependencies.
```

---

## Component Integration

| Component | Type | Purpose | Phase | Model |
|-----------|------|---------|-------|-------|
| `feat2issue-validator` | Agent | Input validation and parsing | 0 | Haiku |
| `idea-creative-proposer` | Agent | Creative brainstorming and research | 1.1 | Opus |
| `idea-critical-checker` | Agent | Rigorous critique and fact-checking | 1.2 | Opus |
| `idea-comprehensive-analyzer` | Agent | Independent synthesis and recommendation | 1.3 | Opus |
| `issue-researcher` | Agent | GitHub issue search | 2 | - |
| `doc-researcher` | Agent | Documentation analysis | 3 | - |
| `issue-creator` | Agent | Issue creation/updates | 5.2 | - |
| `project-manager` | Agent | Project board integration (MANDATORY) | 5.1, 5.3 | - |
| `issue-templates` | Skill | Issue body templates | 5 | - |
| `/update-related-issues` | Command | Issue chain updates | 6 | - |
| `/git-commit` | Command | Commit formatting | 5 | - |

**Project board integration flow:**
- Phase 5.1: Documentation issue → main thread spawns `project-manager`
- Phase 5.3: Implementation issues (from `issue-creator`) → main thread spawns `project-manager` for each

**Note:** Subagents cannot spawn other subagents. The main thread is responsible for spawning `project-manager` after receiving issue numbers.

---

## Notes

### Key Principles

1. **Design before code**: Documentation is finalized before implementation issues are created
2. **Three-stage validation**: Phase 1 uses creative proposal → critical review → independent synthesis
3. **Separation of concerns**: Creative thinking and critical thinking are handled by different agents
4. **No duplicate work**: Phase 2 prevents creating issues that duplicate existing ones
5. **Actionable output**: Each implementation issue should be solvable by `/issue2impl`

### Implementation Issues Guidelines

Implementation issues should contain:
- Clear acceptance criteria (checkboxes)
- Design constraints from documentation
- API signatures (if applicable)
- Test expectations
- References to finalized documentation

Implementation issues should NOT contain:
- Large code blocks
- Detailed implementation steps
- Anything that belongs in the code itself

### Error Handling

- **Phase 1 abandonment**: Stop gracefully if design is deemed unviable after three-agent analysis
- **Phase 1 revision loop**: If analyzer returns REVISION_NEEDED, restart full chain (1.1→1.2→1.3) with user feedback
- **Phase 2 conflicts**: Present options to user (update/close/create)
- **Phase 5 merge failure**: Continue with pending PR, issues reference it
- **Phase 6 chain limit**: Process up to 10 related issues per invocation

### Skill Usage

When the workflow mentions "Use issue-templates skill", invoke the Skill tool to load templates into context before creating issues.
