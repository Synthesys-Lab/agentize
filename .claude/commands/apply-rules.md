---
name: apply-rules
description: Load DSA Stack project rules into context
---

Please read and apply all project rules from `.claude/rules/`:

**Unconditionally Loaded (always active):**
- `language.md` - English-only requirement
- `summary-preferences.md` - No separate summary files

**Path-Specific Rules:**
- `documentation-guidelines.md` - Documentation standards (applies to `**/*.md`)
- `github-workflows-readme-sync.md` - Workflow sync rules (applies to `.github/workflows/*.yml`)

**Other Rules:**
- `agent-handoff-guide.md` - Handoff summary framework
- `file-movement-protocol.md` - Safe file rename/move protocol
- `git-commit-format.md` - Git commit message format

See `.claude/CLAUDE.md` for details.
