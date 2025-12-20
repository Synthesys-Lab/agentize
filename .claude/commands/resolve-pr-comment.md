---
description: Resolve the latest PR comment on the current branch
allowed-tools: Bash(git branch:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh api:*), Bash(git log:*)
---

## Context

- Current branch: !`git branch --show-current`

## Task: Resolve PR Comments

You are tasked with examining and resolving comments on a pull request associated with the current branch. Comments are processed by priority, with **human comments taking precedence over bot comments** and **recent comments taking precedence over older ones**.

### Step 1: Check Current Branch

First, verify the current branch name from the context above.

**If the current branch is `main` or `master`:**
- Notify the user: "No PR found. You are on the main branch. Please create a feature branch and open a PR first."
- Stop execution.

### Step 2: Find Associated PR

Use GitHub CLI to find if there is a PR associated with this branch:

```bash
gh pr list --head "$(git branch --show-current)" --json number,title,state,url --jq '.[] | select(.state == "OPEN")'
```

**If no PR is found:**
- Notify the user: "No PR found for the current branch. Please create a PR using: `gh pr create`"
- Stop execution.

**If PR is found:**
- Display the PR number, title, and URL
- Proceed to the next step

### Step 3: Establish Temporal Reference Point

Before fetching comments, determine the temporal reference point for prioritization.

#### 3a. Get the Most Recent Commit Timestamp

```bash
git log -1 --format='%aI' HEAD
```

This returns the ISO 8601 timestamp of the most recent commit on the current branch.

#### 3b. Get PR Creation Timestamp

```bash
gh pr view {pr_number} --json createdAt --jq '.createdAt'
```

**Store both timestamps for comparison in Step 4.**

### Step 4: Retrieve All PR Comments (Reverse Chronological Order)

Fetch ALL comments from the PR, sorted by most recent first. There are two types of comments to check:

#### 4a. Review Comments (code-level comments)

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq 'sort_by(.created_at) | reverse | .[] | {id, user: .user.login, user_type: .user.type, body, path, line, created_at, updated_at}'
```

#### 4b. Issue Comments (general PR comments)

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq 'sort_by(.created_at) | reverse | .[] | {id, user: .user.login, user_type: .user.type, body, created_at}'
```

**Note**: The `sort_by(.created_at) | reverse` ensures comments are returned most-recent-first.

### Step 5: Categorize Comments by Priority

**CRITICAL**: Apply the following TWO-LEVEL priority system:

1. **Temporal Priority** (PRIMARY): Comments after the most recent commit are prioritized over older comments
2. **Type Priority** (SECONDARY): Within each temporal category, apply the P1-P4 hierarchy

#### Temporal Categorization

For each comment, compare its `created_at` timestamp against the most recent commit timestamp:

| Temporal Category | Condition | Rationale |
|-------------------|-----------|-----------|
| **RECENT** | `created_at` > most recent commit timestamp | Likely unaddressed feedback |
| **OLDER** | `created_at` <= most recent commit timestamp | May have been addressed by subsequent commits |

**Processing Order**:
1. First, process all RECENT comments (by P1 → P4 priority)
2. Then, process OLDER comments (by P1 → P4 priority) only if explicitly requested or if RECENT comments reference them

#### Type Priority Hierarchy (P1-P4)

Within each temporal category, apply this priority order:

**Priority 1 (MUST RESOLVE)** - Human Critical Items:
- Human questions requiring answers
- Human-raised blockers or concerns
- Human-identified bugs or issues
- Human requirements or constraints
- Human objections that need resolution

**Priority 2 (SHOULD RESOLVE)** - Bot/Review Critical Items:
- Code review requested changes (from automated reviewers)
- Bot-identified critical issues or bugs
- CI/CD failures requiring fixes
- Security vulnerabilities flagged by bots
- Blocker-level automated findings

**Priority 3 (CONSIDER)** - Human Suggestions:
- Human implementation suggestions
- Human design recommendations
- Human-proposed alternatives
- Human "nice-to-have" requests
- Human style/convention feedback

**Priority 4 (OPTIONAL)** - Bot/Review Minor Items:
- Bot minor suggestions or warnings
- Code style/lint findings
- Non-critical automated recommendations
- Informational bot comments (coverage reports, etc.)
- CI/CD status updates (passing builds)

#### Identifying Comment Authors

**Bot Detection Patterns**:
- `user.type == "Bot"` in API response
- Login ending with `[bot]` (e.g., `github-actions[bot]`, `dependabot[bot]`)
- Common bot usernames: `github-actions`, `dependabot`, `renovate`, `codecov`, `vercel`, `claude`, `copilot`
- Automated comment patterns: CI status badges, coverage reports, automated review comments

#### Categorizing Comment Content

**For Human Comments, identify**:
- **Questions** (Priority 1): Starts with "?", contains "how", "why", "what", "can you", "could you"
- **Blockers/Concerns** (Priority 1): Contains "blocker", "concern", "issue", "problem", "must", "required", "critical"
- **Suggestions** (Priority 3): Contains "suggest", "consider", "maybe", "could", "might want to", "idea", "nit", "optional"

**For Bot/Review Comments, identify**:
- **Critical** (Priority 2): Contains "error", "critical", "blocker", "required", "must fix", "breaking", "security"
- **Minor** (Priority 4): Contains "warning", "suggestion", "consider", "style", "nitpick", "optional", "info"

### Step 6: Display Comment Analysis

Present a summary table of all comments, organized by temporal category and priority:

```markdown
## PR Comment Analysis

**Temporal Reference**: Most recent commit at `YYYY-MM-DDTHH:MM:SSZ`

---

### RECENT Comments (After Last Commit)

These comments are likely unaddressed and should be the primary focus.

#### Priority 1: MUST RESOLVE (Human Critical)
| # | Author | Date | Type | Summary | Status |
|---|--------|------|------|---------|--------|
| 1 | @human | YYYY-MM-DD HH:MM | Question | Question text | Unresolved |

#### Priority 2: SHOULD RESOLVE (Bot/Review Critical)
| # | Source | Date | Type | Summary | Severity |
|---|--------|------|------|---------|----------|
| 1 | bot-name | YYYY-MM-DD HH:MM | Bug | Description | Critical |

#### Priority 3: CONSIDER (Human Suggestions)
| # | Author | Date | Suggestion | Recommendation |
|---|--------|------|------------|----------------|
| 1 | @human | YYYY-MM-DD HH:MM | Suggestion text | Accept/Defer/Decline |

#### Priority 4: OPTIONAL (Bot Minor)
| # | Source | Date | Type | Summary | Action |
|---|--------|------|------|---------|--------|
| 1 | linter | YYYY-MM-DD HH:MM | Style | Description | Fix if time permits |

---

### OLDER Comments (Before Last Commit)

These comments may have been addressed by subsequent commits. Review only if:
- Referenced by RECENT comments
- Explicitly unresolved
- User requests review

#### Priority 1: MUST RESOLVE (Human Critical)
| # | Author | Date | Type | Summary | Likely Status |
|---|--------|------|------|---------|---------------|
| 1 | @human | YYYY-MM-DD HH:MM | Concern | Concern text | May be resolved |

(Include other priority levels as needed)

---

**Comment Summary**: X total comments
- RECENT: Y comments (focus area)
  - Priority 1 (Human Critical): N items
  - Priority 2 (Bot Critical): N items
  - Priority 3 (Human Suggestions): N items
  - Priority 4 (Bot Minor): N items
- OLDER: Z comments (may be resolved)
  - Priority 1 (Human Critical): N items
  - Priority 2 (Bot Critical): N items
  - Priority 3 (Human Suggestions): N items
  - Priority 4 (Bot Minor): N items
```

### Step 7: Draft Resolution Plan (MANDATORY)

**Before making any code changes, you MUST enter plan mode and get user approval.**

#### 7a. Enter Plan Mode

Use `EnterPlanMode` tool to transition to planning state.

#### 7b. Create Resolution Plan

For each comment that requires action, draft a plan with extended thinking (ultrathink) that includes:

```markdown
## Resolution Plan

### Comments to Address

#### [RECENT P1] Comment from @author at YYYY-MM-DD HH:MM
**Comment**: "Original comment text"
**File**: path/to/file.cpp:line
**Analysis**:
- Is this feedback valid? Why/why not?
- What changes are needed?
- Any edge cases or implications?

**Proposed Action**:
- [ ] Action item 1
- [ ] Action item 2

**Estimated Impact**: Files affected, lines to change

---

#### [RECENT P2] Bot review finding
**Comment**: "Finding description"
**File**: path/to/file.cpp:line

**Proposed Action**:
- [ ] Action item

---

### Summary of Proposed Changes

| File | Change Type | Description |
|------|-------------|-------------|
| file1.cpp | Modify | Description of change |
| file2.h | Add | Description of addition |

### Risk Assessment

- **Breaking changes**: Yes/No - explanation
- **Test impact**: Tests to run/update
- **Dependencies**: Any dependent code affected
```

#### 7c. Request User Approval

Present the plan to the user and explicitly ask:

```markdown
## Approval Required

I have analyzed the PR comments and drafted a resolution plan above.

**Please review and confirm:**
1. Do you approve the proposed changes?
2. Should any items be skipped or modified?
3. Are there any additional concerns?

Reply with:
- "Approved" - Proceed with all proposed changes
- "Approved with modifications: [details]" - Proceed with specified changes
- "Reject" - Stop and discuss further
```

**Do NOT proceed to Step 8 without explicit user approval.**

### Step 8: Implement Approved Changes

Only after receiving user approval, implement the changes:

#### For Priority 1 (Human Critical) - MANDATORY:

1. **Examine the codebase in-depth:**
   - Read the relevant files mentioned in the comment
   - Understand the context around the commented code
   - Check if the issues or suggestions raised are valid

2. **Implement approved changes:**
   - Follow the approved plan exactly
   - Use extended thinking for complex changes
   - Explain what was changed and why

3. **If the feedback is not applicable or already addressed:**
   - Explain why the feedback doesn't apply
   - Provide evidence from the codebase
   - Prepare a response for the commenter

4. **For questions:**
   - Provide a helpful response with context from the codebase
   - Suggest the user post the response as a comment

#### For Priority 2 (Bot/Review Critical) - SHOULD RESOLVE:

- Address critical automated findings
- Fix security vulnerabilities
- Resolve CI/CD blockers
- Implement required changes from automated reviewers

#### For Priority 3 (Human Suggestions) - CONSIDER:

- Evaluate each suggestion for merit
- Accept if it improves the code
- Defer if out of scope for this PR
- Decline with rationale if not appropriate

#### For Priority 4 (Bot Minor) - OPTIONAL:

- Address if time permits
- Fix style issues that are quick wins
- Acknowledge informational comments

### Step 9: Summary

After processing, provide a comprehensive summary:

```markdown
## Resolution Summary

### Temporal Overview
- **RECENT comments processed**: X of Y
- **OLDER comments reviewed**: Z (if applicable)

### Resolved Items
| Temporal | Priority | Item | Action Taken |
|----------|----------|------|--------------|
| RECENT | P1 | @human's question about X | Answered with code reference |
| RECENT | P2 | Bot security warning | Fixed in file.cpp:123 |
| OLDER | P1 | @human's concern about Y | Already addressed in commit ABC |

### Pending Items (Need Human Attention)
| Temporal | Priority | Item | Reason |
|----------|----------|------|--------|
| RECENT | P1 | Design decision about Y | Requires user input |

### Changes Made
- File 1: Description of change
- File 2: Description of change

### Suggested Responses
For comments that need a reply, provide suggested response text.

### OLDER Comments Status
| Comment | Status | Evidence |
|---------|--------|----------|
| @human's concern from Day 1 | Likely resolved | Addressed in commit XYZ |
| Bot finding from Day 2 | Superseded | Fixed in later commit |
```

## Important Notes

- **Temporal priority is critical** - RECENT comments (after last commit) should be addressed first
- **Human comments MUST be resolved** - Priority 1 items are blockers within each temporal category
- **Plan mode is MANDATORY** - Never make changes without user approval on the plan
- Always verify the validity of review comments before making changes
- Use extended thinking for complex code changes
- Follow the project's coding standards and commit message format
- Do not automatically commit changes - let the user review first
- If multiple Priority 1 items exist, resolve ALL of them (RECENT first, then OLDER if needed)
- Bot comments (Priority 2, 4) should not block human comment resolution
- OLDER comments may already be resolved - check commit history before acting
