# Summary and Modification Reporting Preferences

## No Separate Summary Documents

The user prefers **NOT** to have separate markdown files created for summaries or changelogs.

### Required Behavior

When the AI completes modifications or needs to summarize changes:
- [OK] **DO**: Reply directly with the summary in the conversation
- [ERROR] **DON'T**: Create separate `.md` files like `CHANGELOG.md`, `SUMMARY.md`, or similar

### Examples

**Correct approach**:
```
I've completed the modifications to the script. Here's what changed:
1. Extended file scanning to include .mlir, .cpp, .hpp files
2. Added support for tests/ directory
3. Updated documentation strings
```

**Incorrect approach**:
```
Let me create a summary document...
[Creates CHANGELOG_modifications.md]
```

### Exception

This rule does **NOT** apply to:
- Project documentation (README.md, DIALECT.md, etc.)
- Required documentation per documentation-guidelines rule
- Test documentation
- Code comments and inline documentation

The preference is specifically about **temporary summary/changelog files** created to report what the AI just did.
