# Claude Code for MyProject

## Project Overview

TODO: Add project description

<!-- TODO: Add detailed project description, architecture overview, and key components -->

## Documentation

| Folder | Purpose |
|--------|---------|
| `docs/` | Project README and top-level docs |
| `docs/draft/` | Ideas, drafts, incomplete work, RFCs |
| `docs/roadmap/` | High-level planning and future directions |
| `docs/architecture/` | Finalized design specs |

### Core Docs

<!-- TODO: List your main documentation files here -->
- @docs/CLAUDE.md - Project documentation
- @docs/architecture/ - Design specifications
- @docs/roadmap/ - Implementation priorities

For directory-specific docs, see README.md in each subdirectory.

## Rules

Rules in `.claude/rules/` are automatically loaded.

### Always Loaded
- `language.md` - English-only for all repository content
- `summary-preferences.md` - Reply directly; no separate summary files

### Path-Specific
<!-- TODO: Configure path-specific rules for your project -->
- `documentation-guidelines.md` - Documentation standards (`**/*.md`)
- `github-workflows-readme-sync.md` - Workflow sync (`.github/workflows/*.yml`)

### Reference Rules
- `milestone-guide.md` - Multi-session milestone framework
- `file-movement-protocol.md` - Safe file rename/move protocol
- `git-commit-format.md` - **MUST check before any `git commit`**

## Build Commands

### Environment Setup
```bash
source setup.sh              # Load development environment
```

### Full Build
```bash
make build                   # Build the entire project
```

<!-- TODO: Add your project-specific build commands -->

### Testing
```bash
make test                    # Run all tests
```

## Component Tags

${COMPONENT_TAGS}

<!-- TODO: Define what each component tag represents in your project
Example:
- [CORE] - Core library/framework
- [API] - REST API implementation
- [UI] - User interface components
- [TEST] - Testing utilities
- [DOCS] - Documentation
-->

## Project-Specific Tools

<!-- TODO: List your project's custom tools and their purposes
Example:
| Tool | Purpose |
|------|---------|
| `tool-name` | Description |
-->

## Code Comment Rules

- **NEVER** use these in comments: `FIXED`, `Step`, `Week`, `Section`, `Phase` (planning references)
- **Exception**: Algorithmic steps within functions are OK (e.g., "Step 1: Initialize")
- For lengthy explanations: open a GitHub issue with `gh` and reference as `ISSUE#XYZ` or `PR#XYZ`

## Custom Project Rules

See `.claude/rules/custom-project-rules.md` for project-specific guidelines.

## Slash Commands

- `/apply-rules` - Load project rules into context

<!-- TODO: Add custom commands specific to your project -->

---

**Customization Guide**: See `.claude/PROJECT_CONFIG.md` for detailed instructions on customizing this configuration.
