# Design Draft: Split input-validator into Workflow-Specific Validators

**Created**: 2025-12-21 09:52:52
**Status**: Draft - Brainstorming Complete

## Executive Summary

Split the shared `input-validator.md` agent into two dedicated validators: `feat2issue-validator.md` and `issue2impl-validator.md`. This is a low-risk organizational refactoring that improves clarity by giving each command its own dedicated validation agent, with no shared logic to duplicate.

## Problem Statement

The current `input-validator.md` serves two distinct workflows (`feat2issue` and `issue2impl`) with completely independent validation logic. While functional, this creates a single file that must internally route based on a `workflow` parameter. Splitting into dedicated validators would:
- Simplify each validator file
- Align with single-responsibility principle
- Make each command's validation more discoverable

## Design Decision Record

### Key Decisions Made

| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Split approach | Direct Split | Simplest, lowest risk | Pipeline, Schema-driven, Hybrid (all rejected as over-engineering) |
| File naming | `feat2issue-validator.md`, `issue2impl-validator.md` | Workflow-prefixed, concise | `*-input-validator.md` (too long) |
| Shared code handling | None needed | No shared logic exists between workflows | Base class (rejected - nothing to share) |

### Critical Issues Resolved

1. **"Creates duplication" concern**: Analyzed and found NO shared validation logic between workflows - each has unique checks
2. **"Missing justification" concern**: User explicitly requested the split; organizational clarity is valid justification for low-risk refactoring

### Acknowledged Tradeoffs

1. **Two files instead of one**: Accepted because each file is self-contained and simpler
2. **Slightly more to maintain**: Mitigated by the fact that validators rarely change and are independent

## Design Specification

### Overview

Replace the single `input-validator.md` agent with two workflow-specific agents:
- `feat2issue-validator.md`: Validates input for `/feat2issue` (text/file detection)
- `issue2impl-validator.md`: Validates input for `/issue2impl` (issue/branch/dependency checks)

### Key Components

1. **feat2issue-validator.md**
   - Purpose: Validate and parse `/feat2issue` input (text or file path)
   - Checks: Empty input, input type detection, file validation
   - Output: IDEA_CONTENT for subsequent phases

2. **issue2impl-validator.md**
   - Purpose: Validate `/issue2impl` prerequisites
   - Checks: Issue number format, branch name, issue existence, dependencies
   - Output: Validation status table

### Files to Modify

| File | Change |
|------|--------|
| `.claude/agents/input-validator.md` | DELETE |
| `.claude/agents/feat2issue-validator.md` | CREATE (new) |
| `.claude/agents/issue2impl-validator.md` | CREATE (new) |
| `.claude/commands/feat2issue.md` | Update spawn reference (line 32, 483) |
| `.claude/commands/issue2impl.md` | Update spawn reference (line 18, 345) |
| `.claude/README.md` | Update diagrams and component tables |

### Constraints

1. Both validators must use `model: haiku` (same as current)
2. Output formats must remain identical to current behavior
3. Spawn contexts in commands need only change the agent name

## Research References

### Internal References
- `.claude/agents/input-validator.md`: Current shared validator (229 lines)
- `.claude/commands/feat2issue.md`: Phase 0 spawns validator
- `.claude/commands/issue2impl.md`: Phase 1 spawns validator

### External References
- None needed - this is internal organizational refactoring

## Open Questions

None - design is straightforward.

## Implementation Plan

### Step 1: Create feat2issue-validator.md
Extract lines 111-184 from current validator, add frontmatter:
```yaml
---
name: feat2issue-validator
description: Validate inputs for /feat2issue workflow. Returns PASS or FAIL with IDEA_CONTENT.
tools: Read
model: haiku
---
```

### Step 2: Create issue2impl-validator.md
Extract lines 23-107 from current validator, add frontmatter:
```yaml
---
name: issue2impl-validator
description: Validate inputs for /issue2impl workflow. Returns PASS, WARNING, or FAIL.
tools: Bash(git branch:*), Bash(gh issue view:*), Bash(gh issue list:*)
model: haiku
---
```

### Step 3: Update command files
- `feat2issue.md`: Change `input-validator` to `feat2issue-validator`
- `issue2impl.md`: Change `input-validator` to `issue2impl-validator`

### Step 4: Update README.md
- Update diagrams (IV and IV2 labels)
- Update component tables

### Step 5: Delete input-validator.md
After confirming both new validators work correctly.

## Next Steps

This design is ready for:
1. Implementation issue creation
2. Development via `/issue2impl`

---

*This draft was created through a three-stage brainstorming process: creative proposal, critical review, and independent synthesis.*
