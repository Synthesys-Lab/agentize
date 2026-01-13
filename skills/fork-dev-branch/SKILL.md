---
name: fork-dev-branch
description: Create a development branch for a given GitHub issue with standardized naming
---

# Fork Dev Branch

This skill instructs AI agents on how to create a development branch for implementing
a GitHub issue. The branch name follows the standard format: `issue-<number>`.

## Branch Naming Convention

Branches created by this skill must follow this exact format:

```
issue-<number>
```

Where:
- `<number>`: The GitHub issue number (without the `#` symbol)

**Examples:**
- `issue-42`
- `issue-15`
- `issue-67`
- `issue-23`

**Rationale:** GitHub issues provide full context (title, description, labels, etc.). Branch names only need the issue number for identification. This simplifies branch creation and treats issues as the single source of truth.

## Workflow for AI Agents

When this skill is invoked, the AI agent **MUST** follow these steps:

### 1. Extract and Verify Issue Number

Find the issue number from conversation context:
- Look for explicit references: "for issue #42", "implement #15", etc.
- If not found, check recent issues: `gh issue list --limit 10`
- If still unclear, ask the user: "Which issue number should this branch be for?"
- Accept numbers with or without `#` prefix (e.g., "42" or "#42")

Verify the issue exists and is open:
```bash
gh issue view <issue-number> --json state,title
```

If the issue is closed or doesn't exist, inform the user and abort.

### 2. Create Branch

Create and switch to the new branch:

```bash
git checkout -b issue-<number>
```

Confirm success:
```
Successfully created and switched to branch: issue-<number>
```

## Examples

### Example 1: Simple Feature Branch

**Context:** User wants to implement issue #42 for TypeScript SDK support.

**Conversation:**
```
User: Create a dev branch for issue #42
Agent: [Runs gh issue view 42]
Agent: I'll create a branch for issue #42: "Add TypeScript SDK template support"

Creating branch...
[Runs: git checkout -b issue-42]

Successfully created and switched to branch: issue-42
```

### Example 2: Bugfix Branch

**Context:** User wants to fix issue #15.

**Conversation:**
```
User: fork a branch for #15
Agent: [Runs gh issue view 15]
Agent: I'll create a branch for issue #15: "Pre-commit hook fails to run tests"

Creating branch...
[Runs: git checkout -b issue-15]

Successfully created and switched to branch: issue-15
```

### Example 3: Error - Invalid Issue Number

**Context:** User provides a non-existent issue number.

**Conversation:**
```
User: Create dev branch for issue 999
Agent: [Runs gh issue view 999]
Agent: Error: Issue #999 not found in this repository.

Please provide a valid issue number.
```
