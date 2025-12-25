# Tutorial 01: Plan an Issue

**Read time: 3-5 minutes**

This tutorial explains how to create implementation plans and GitHub issues using the Agentize framework.

## What is `/plan-an-issue`?

`/plan-an-issue` creates GitHub issues tagged with `[plan][tag]` that contain detailed implementation plans. These issues serve as blueprints for implementing features, refactoring code, or fixing bugs.

The tags come from `docs/git-msg-tags.md` (see Tutorial 00 for customization).

## Prerequisites

Before using `/plan-an-issue`, you need an implementation plan. You can get one by:

1. **Using `/make-a-plan`**: Let the AI create a detailed plan from your requirements
2. **Providing a plan file**: If you already have a plan document

## Typical Workflow

### Step 1: Create a Plan with `/make-a-plan`

Start by describing what you want to implement:

```
User: I need to add TypeScript SDK template support to the project
```

The AI will create a detailed implementation plan including:
- Files to create or modify
- Step-by-step implementation approach
- LOC estimates for each step
- Test strategy
- Architectural considerations

### Step 2: Review and Approve the Plan

The AI will present the plan for your review. You can:
- Approve it as-is
- Request modifications
- Ask clarifying questions

### Step 3: Create the GitHub Issue with `/plan-an-issue`

Once you're satisfied with the plan:

```
/plan-an-issue
```

The AI will:
1. Review tag standards in `docs/git-msg-tags.md`
2. Determine the appropriate tag (e.g., `[plan][feat]`, `[plan][docs]`, `[plan][refactor]`)
3. Draft the issue with proper formatting
4. Confirm with you before creating it on GitHub

## Issue Format

Issues created by `/plan-an-issue` follow this structure:

```markdown
Title: [plan][tag] Brief description

## Problem Statement
Description of what needs to be done and why

## Proposed Solution
[The implementation plan goes here]

## Test Strategy
How the changes will be tested
```

## Tag Selection

The AI automatically selects tags from `docs/git-msg-tags.md`. Common tags include:

- `[plan][feat]`: New features
- `[plan][docs]`: Documentation updates
- `[plan][bugfix]`: Bug fixes
- `[plan][refactor]`: Code refactoring
- `[plan][test]`: Test-only changes
- `[plan][agent.skill]`: New or modified skills
- `[plan][agent.command]`: New or modified commands

If you customized tags in Tutorial 00, those will be available too.

## When to Use `/plan-an-issue`

Use this command for:
- **New features** requiring detailed implementation steps
- **Refactoring tasks** with multiple file changes
- **Bug fixes** that need a structured approach
- **Improvements** with specific implementation details

Don't use it for:
- Simple one-line fixes
- Trivial documentation updates
- Tasks without clear implementation steps

## Example Walkthrough

Let's walk through planning a new feature:

**1. User provides requirements:**
```
User: I want to add support for Rust projects. The SDK should generate proper Rust project structure with cargo configuration.
```

**2. AI creates a plan using `/make-a-plan`:**
```
Agent: I'll create a detailed plan for adding Rust SDK support.
[Creates plan with:
 - New template files to create
 - Makefile modifications
 - Test cases for Rust projects
 - LOC estimates: ~450 LOC total]

Agent: Here's the plan. Does this approach look good?
```

**3. User approves:**
```
User: Yes, looks good
```

**4. AI creates the issue:**
```
User: /plan-an-issue

Agent: I'll create a [plan][feat] issue for this implementation.

Title: [plan][feat] Add Rust SDK template support

[Shows draft issue...]

Agent: Should I create this issue on GitHub?

User: Yes

Agent: Issue created: https://github.com/your-repo/issues/45
```

## Using a Plan File Directly

If you have a plan document already:

```
/plan-an-issue docs/draft/my-plan.md
```

The AI will read the plan from that file and create the issue.

## Next Steps

After creating a [plan] issue:
- **Tutorial 02**: Learn how to implement the issue with `/issue-to-impl`, `/code-review`, and `/sync-master`

## Tips

1. **Be specific in requirements**: The more details you provide, the better the plan
2. **Review carefully**: Implementation follows the plan closely
3. **Ask questions**: Clarify anything unclear before approving
4. **Keep plans focused**: One feature or fix per issue works best
5. **Use custom tags**: Add project-specific tags in `docs/git-msg-tags.md` for better organization
