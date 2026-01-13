# Doc-Architect Skill

Analyzes a feature implementation plan and generates a comprehensive documentation checklist covering design docs, folder READMEs, and interface documentation.

## Purpose

Ensures documentation impacts are systematically identified during planning, avoiding documentation debt and ensuring all required docs are created/updated during implementation.

## Usage

```
/doc-architect
```

The skill analyzes the current feature requirements from conversation context and produces a Documentation Planning section.

## Output Format

```markdown
## Documentation Planning

### High-level design docs (docs/)
- `docs/workflows/feature-name.md` — create/update workflow documentation
- `docs/tutorial/XX-feature-name.md` — create/update tutorial with new feature

### Folder READMEs
- `path/to/module/README.md` — update purpose and organization

### Interface docs
- `src/module/component.md` — update interface documentation
```

## Integration

This skill is designed to be invoked during planning workflows (e.g., `/ultra-planner`, `/make-a-plan`) to produce the Documentation Planning section that gets included in the consensus plan. The `/issue-to-impl` workflow consumes this section in Step 5 (documentation updates).
