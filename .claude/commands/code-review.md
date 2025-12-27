---
name: code-review
description: Review code changes from current HEAD to main/HEAD following review standards
---

# Code Review Command

Execute the review-standard skill to perform comprehensive code review of changes on the current branch.

Invoke the skill: /code-review

**Note**: For large diffs or comprehensive reviews requiring long context analysis, consider using the `code-quality-reviewer` agent which runs on Opus model in isolated context. The agent provides the same review standards with enhanced capacity for thorough analysis.

## Inputs

**From git:**
- Current branch name (for validation and report header)
- Changed files: `git diff --name-only main...HEAD`
- Full diff: `git diff main...HEAD`

**From repository:**
- Documentation linter: `scripts/lint-documentation.sh`
- Existing utilities for reuse checks
- Project conventions and patterns

## Outputs

**Terminal output:**
- Structured review report with sections:
  - Phase 1: Documentation Quality Review
  - Phase 2: Code Quality & Reuse Review
  - Overall Assessment with recommendations

**Review categories:**
- ✅ APPROVED - Ready for merge
- ⚠️  NEEDS CHANGES - Minor issues to address
- ❌ CRITICAL ISSUES - Must fix before merge

## Skill Integration

### Step 1: Validate Current Branch

Check that the current branch is not main:

```bash
git branch --show-current
```

If on main branch:
```
Error: Cannot review changes on main branch.

Please switch to a development branch (e.g., issue-N-feature-name)
```
Stop execution.

### Step 2: Get Changed Files

Retrieve list of all files changed between main and current HEAD:

```bash
git diff --name-only main...HEAD
```

If no changes found:
```
No changes detected between main and current branch.

Nothing to review.
```
Stop execution.

### Step 3: Get Full Diff

Retrieve complete diff of all changes:

```bash
git diff main...HEAD
```

This provides the full context of changes for the review-standard skill.

### Step 4: Invoke Review-Standard Skill

Execute the review-standard skill with gathered context:

**Inputs to skill:**
- Current branch name
- List of changed files
- Full diff content
- Repository root path

The skill performs a comprehensive three-phase review (see `claude/skills/review-standard/SKILL.md` for details):
- Phase 1: Documentation Quality Review
- Phase 2: Code Quality & Reuse Review
- Phase 3: Advanced Code Quality Review

**Skill output:**
- Structured review report with findings

### Step 5: Display Review Report

Present the formatted review report to the user with:
- Branch name and change summary
- Phase 1 findings (documentation quality)
- Phase 2 findings (code quality & reuse)
- Phase 3 findings (advanced code quality)
- Overall assessment (APPROVED / NEEDS CHANGES / CRITICAL ISSUES)
- Specific, actionable recommendations

Example output format:
```
# Code Review Report

**Branch**: issue-42-feature-name
**Changed files**: 8 files (+450, -120 lines)

---

## Phase 1: Documentation Quality

### ✅ Passed
- All folders have README.md files

### ❌ Issues Found
- Location: src/utils/parser.py
  Standard: Phase 1, Check 3 — Source Code Interface Documentation
  Recommendation: Create parser.md documenting interfaces

---

## Phase 2: Code Quality & Reuse

### ❌ Issues Found
- Location: src/api/handler.py:67
  Standard: Phase 2, Check 2 — Local Utility Reuse
  Recommendation: Use existing validate_json() utility instead of manual validation

---

## Phase 3: Advanced Code Quality

### ✅ Passed
- No unnecessary indirection detected

### ⚠️  Warnings
- Location: src/utils/parser.py:15
  Standard: Phase 3, Check 5 — Type Safety & Magic Numbers
  Recommendation: Add type annotations to parse_input()

---

## Overall Assessment

**Status**: ⚠️  NEEDS CHANGES

**Recommended actions before merge**:
1. Create parser.md documenting interfaces
2. Use existing validate_json() utility
3. Add type annotations to parse_input()
```

## Error Handling

### Not on Git Repository

```bash
git branch --show-current
# Error: not a git repository
```

**Response:**
```
Error: Not in a git repository.

Please run this command from within a git repository.
```
Stop execution.

### Main Branch Detection

```bash
git branch --show-current
# Output: main
```

**Response:**
```
Error: Cannot review changes on main branch.

Please switch to a development branch:
  git checkout -b issue-N-feature-name

Or switch to existing branch:
  git checkout issue-N-feature-name
```
Stop execution.

### No Changes Found

```bash
git diff --name-only main...HEAD
# Output: (empty)
```

**Response:**
```
No changes detected between main and current branch.

Your branch is synchronized with main. Nothing to review.
```
Stop execution.
