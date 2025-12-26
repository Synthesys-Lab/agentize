# Review Standard Skill

This directory contains the review-standard skill for comprehensive code review of changes.

## Purpose

The review-standard skill provides AI agents with systematic guidance for reviewing code changes
before merging to main. It ensures quality, consistency, and adherence to project documentation
and code reuse standards.

## Integration

This skill is invoked by the `/code-review` command and integrates with:
- `document-guideline` skill - References documentation standards for review criteria
- `scripts/lint-documentation.sh` - Uses for structural documentation validation
- Git and GitHub CLI - For accessing change diffs and repository context

## Implementation

The skill was simplified from 1042 to 495 lines (52% reduction) while preserving analytical depth:
- Condensed verbose procedural instructions into concise guidelines
- Removed redundant bash examples (agents understand git commands)
- Maintained all 6 Phase 3 specialized checks
- Preserved evidence requirements and severity classification

## Usage

See `SKILL.md` for complete review process and standards.
