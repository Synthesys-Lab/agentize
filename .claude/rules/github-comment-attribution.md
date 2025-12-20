# GitHub Comment Attribution Rule

## Purpose

Since GitHub comments are posted under the user's account, comments authored by Claude Code AI must be clearly attributed to avoid misrepresentation.

## Required Attribution

All GitHub issue and PR comments written by Claude Code AI **MUST** include an attribution prefix at the beginning of the comment:

```markdown
*[Comment by Claude Code AI Agent]*

<actual comment content>
```

### Examples

**Correct** (with attribution):
```markdown
*[Comment by Claude Code AI Agent]*

## Implementation Status Update

PR #129 has been created to resolve this issue.
...
```

**Correct** (with attribution):
```markdown
*[Comment by Claude Code AI Agent]*

Thank you for the feedback. This has been addressed in commit abc123.
```

## Exception: Functional Trigger Comments

Comments that serve as **functional triggers** for bots or GitHub Apps do NOT require attribution. These are commands intended to invoke automated actions.

### Exempt Patterns

- `@claude` followed by a command
- `@claude review this PR`
- `@claude Please review...`
- Any comment primarily consisting of a bot/app mention with a command

### Exception Examples

**No attribution needed**:
```markdown
@claude Please review this PR for issue #124.
```

**No attribution needed**:
```markdown
@dependabot rebase
```

## Rationale

1. **Transparency**: Readers should know when a comment was AI-generated vs. human-written
2. **Accountability**: Clear attribution helps maintain trust in project communications
3. **Audit Trail**: Makes it easier to distinguish AI contributions during code review

## Scope

This rule applies to:
- Issue comments (`gh issue comment`)
- PR comments (`gh pr comment`)
- PR review comments

This rule does NOT apply to:
- Commit messages (covered by git-commit-format.md)
- PR/Issue titles
- PR/Issue body content (these are typically reviewed before submission)
