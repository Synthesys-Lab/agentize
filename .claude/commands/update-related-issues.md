---
name: update-related-issues
description: Update GitHub issues based on current codebase status, chain to related issues
argument-hint: <issue-number>
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(gh repo view:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh issue edit:*), Bash(gh issue close:*), Bash(gh issue comment:*), Bash(gh api:*), Bash(gh search issues:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr diff:*), Bash(gh run view:*), Bash(gh run list:*), Bash(gh label list:*), Bash(gh project list:*), Bash(gh project field-list:*), Bash(gh project view:*), Bash(gh project item-list:*)
---

## Context

- Repository: !`gh repo view --json nameWithOwner -q '.nameWithOwner'`
- Original issue number: $1

## Task: Update Issue and Related Issues Based on Codebase Status

You are tasked with analyzing GitHub issue #$1 and updating it based on the current state of the codebase. After processing the original issue, find and process all related issues in a chain.

### Phase 1: Validate Input or Infer from Current Branch

**If no issue number is provided ($1 is empty):**

1. **Check for PR on current branch:**
   ```bash
   gh pr view --json number,title,body,url 2>/dev/null
   ```

2. **If PR exists**, extract issue references from it:
   - Search PR title and body for patterns: `#123`, `Fixes #123`, `Closes #123`, `Related to #123`
   - Use regex to extract issue numbers: `grep -oE '#[0-9]+' | head -1 | tr -d '#'`

3. **If issue number found in PR:**
   - Notify user: "No issue number provided. Found PR #X referencing issue #Y. Using #Y."
   - Continue with that issue number

4. **If no PR or no issue reference found:**
   - Notify the user: "Usage: /update-related-issues <issue-number>"
   - Also suggest: "Tip: Create a PR or specify an issue number explicitly."
   - Stop execution.

### Phase 2: Fetch Original Issue

Use GitHub CLI to fetch the issue details:

```bash
gh issue view $1 --json number,title,body,state,labels,assignees,comments,createdAt,updatedAt
```

**If issue is not found or already closed:**
- For not found: Notify user and stop
- For closed: Ask user if they want to reopen and analyze, or skip

Display issue summary:
- Number and title
- Current state
- Labels
- Key requirements/items from the body

### Phase 3: Deep Codebase Analysis (Use Task Tool)

**CRITICAL**: Use the Task tool with `subagent_type: "Explore"` for thorough codebase analysis.

Spawn an Explore subagent with a prompt like:

```
Analyze the codebase to verify the status of GitHub issue #$1.

Issue title: [title]
Issue requirements:
[extracted requirements from issue body]

For each requirement or TODO item in the issue:
1. Search for relevant files, functions, and implementations
2. Check if the feature/fix has been implemented
3. Look for related tests
4. Note any partial implementations

Return a structured report:
- COMPLETED items (with file:line evidence)
- INCOMPLETE items (with what's missing)
- PARTIALLY COMPLETE items (with current state)
- Any NEW issues discovered during analysis
```

Use extended thinking (ultrathink) to reason through complex issues.

### Phase 4: Determine Issue Disposition

Based on the Explore subagent's findings, determine the action:

#### Case A: All Items Resolved

If ALL requirements are complete AND future work is tracked in other issues:

1. Draft a closing comment summarizing:
   - What was completed
   - File/commit references where applicable
   - Links to any follow-up issues

2. Post the comment and close the issue:
```bash
gh issue comment $1 --body "..."
gh issue close $1 --reason completed
```

#### Case B: Partially Complete

If SOME items are resolved but others remain:

1. Update the issue body with current status:
   - Mark completed items (use checkboxes or strikethrough)
   - Add notes on current implementation status
   - Keep incomplete items clearly visible

2. Update via:
```bash
gh issue edit $1 --body "..."
```

3. Optionally add a progress comment

#### Case C: No Progress / Outdated

If the issue is outdated or requirements have changed:

1. Add a comment explaining the current situation
2. Suggest whether to:
   - Update requirements
   - Close as won't-fix
   - Keep open with modifications

### Phase 5: Find Related Issues

Search for issues related to the one just processed:

#### Method 1: Label-based search
```bash
gh issue list --label "<label-from-original>" --json number,title,state
```

#### Method 2: Keyword search
```bash
gh search issues "repo:<owner>/<repo> <keywords-from-issue>" --json number,title,state
```

#### Method 3: Check issue body for references
Look for patterns like:
- `#123` (issue references)
- `Related to #...`
- `Blocked by #...`
- `See also #...`

#### Method 4: API search for linked issues
```bash
gh api repos/{owner}/{repo}/issues/$1/timeline --jq '[.[] | select(.event == "cross-referenced")] | .[].source.issue.number'
```

Collect all related issue numbers that:
- Are still OPEN
- Have NOT been processed in this session

### Phase 6: Chain Processing

For each related issue found:

1. **Track processed issues** to avoid infinite loops (maintain a list of processed issue numbers)

2. **Spawn a new Task** for each unprocessed related issue:
   - Use Task tool with `subagent_type: "general-purpose"`
   - Pass the issue number and context
   - The subagent should perform Phases 2-4 for that issue

3. **Collect results** from each Task

4. **Continue the chain**: After processing a related issue, check if IT has related issues that haven't been processed yet

### Phase 7: Final Summary

After all issues in the chain have been processed, provide a summary:

```
## Issue Update Summary

### Processed Issues
| Issue | Title | Action Taken |
|-------|-------|--------------|
| #97   | ...   | Closed       |
| #23   | ...   | Updated      |
| #45   | ...   | No changes   |

### Actions Taken
- Closed X issues as completed
- Updated Y issues with progress
- Left Z issues unchanged

### Remaining Work
- Issue #XX: [brief description of what's left]
- Issue #YY: [brief description of what's left]

### New Issues Discovered
- [Any new problems found during codebase analysis]
```

## Important Guidelines

### For Codebase Analysis
- Use Explore subagent for read-only codebase searches
- Look for implementation evidence: functions, classes, tests
- Check git history if relevant (`git log --oneline --grep="..."`)
- Verify tests exist and pass for completed features

### For Issue Updates
- Be conservative: don't close unless genuinely complete
- Preserve original issue content when updating (append, don't replace)
- Use clear formatting for status updates
- Reference specific files and line numbers when possible

### For Chain Processing
- Maximum depth: Process up to 10 related issues per invocation
- Avoid processing the same issue twice
- Process in order of relevance (most related first)
- If chain is too large, summarize remaining issues for manual review

### Decision Criteria for Closing

Close an issue ONLY if:
1. All explicitly listed requirements are implemented
2. Relevant tests exist (if applicable)
3. No blocking sub-tasks remain open
4. Future enhancements are tracked in separate issues

Keep open if:
1. Any requirement is incomplete
2. Implementation exists but lacks tests
3. Partial implementation needs completion
4. Requirements are unclear and need clarification

## Error Handling

- If GitHub API rate limits are hit, pause and notify user
- If an issue cannot be accessed (permissions), skip and note
- If codebase analysis times out, provide partial results
- Always maintain the processed issues list to prevent loops
