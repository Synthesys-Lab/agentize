# SDK Update Mode Design Specification

**Created**: 2025-12-21
**Status**: Approved
**Related Draft**: `docs/draft/agentize-update-mode-20251221-095709.md`

## Overview

This document specifies the design and implementation of the "update" mode for the Agentize SDK installation system. Update mode enables users to refresh their `.claude/` configurations to match the latest SDK version while preserving project-specific customizations.

### Motivation

Currently, Agentize supports `init` (full project initialization) and `port` (minimal `.claude/` installation) modes. When the SDK evolves with new agents, commands, or rules, users have no safe way to adopt improvements without either manually copying files (error-prone), deleting `.claude/` and re-running port (loses customizations), or tracking changes manually (impractical).

Update mode solves this by automating SDK updates while protecting user customizations.

### Core Requirements

1. **Safety**: Never lose user customizations
2. **Transparency**: Users understand what changes and what is preserved
3. **Recoverability**: Easy rollback if something goes wrong
4. **Non-Breaking**: Existing init/port modes remain unchanged
5. **Simplicity**: Minimal implementation complexity

## Design Decisions

### Strategy Selection: Selective Copy

After evaluating multiple approaches (three-way merge, layered directories, git submodules, symlinks), we chose **selective copy with file ownership categories**.

**Rationale**:
- Non-breaking: Works with current `.claude/` directory structure
- No external dependencies: Pure bash implementation
- Simple mental model: Users understand "SDK files" vs "my files"
- Backward compatible: Existing installations work without modification

**Rejected alternatives**:
- **Three-way merge**: Markdown files lack semantic merge tools; conflicts require manual resolution anyway
- **Layered base/overrides architecture**: Claude Code does not support merging multiple `.claude/` directories (verified via official documentation)
- **Git submodules**: Notorious UX issues; requires git repo; adds complexity
- **Symlinks**: Poor Windows support; fragile (breaks if SDK moves); not portable

### Claude Code Compatibility

**Critical finding**: Claude Code uses a **precedence hierarchy** where "more specific scopes take precedence" but settings are **NOT merged** ([Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)).

This eliminates layered directory proposals (`.claude/base/` + `.claude/overrides/`) without implementing a flattening mechanism.

### File Ownership Model

Files are categorized into three ownership types:

| Category | Update Behavior | Examples |
|----------|-----------------|----------|
| **SDK-owned** | Always replaced | `agents/*.md`, `commands/*.md`, `skills/**/*`, `hooks/**/*`, most `rules/*.md` |
| **User-owned** | Never touched | `rules/custom-project-rules.md`, `rules/custom-workflows.md` |
| **Templated** | Prompt user | `CLAUDE.md`, `git-tags.md`, `settings.json`, `PROJECT_CONFIG.md` |

### Templated File Handling

Templated files contain project-specific values (`${PROJECT_NAME}`, `${MASTER_PROJ}`) and cannot be auto-merged.

**Chosen approach**: Interactive prompts with diff preview

**User workflow**:
1. Detect if SDK template changed since installation
2. Show diff between current file and new template
3. Prompt: `[s]kip`, `[o]verwrite`, `[d]iff` (show again), `[q]uit`
4. Respect user choice

### Deletion Semantics (Orphaned Files)

**Decision**: Report orphaned files but **never auto-delete**.

Orphaned files are files present in target `.claude/` but not in current SDK.

**Rationale**: Safety-first; deleting files is irreversible; ambiguous (can't distinguish user-created files from removed SDK files).

## File Ownership Specification

### SDK-Owned Files (Always Replaced)

```
.claude/
├── agents/*.md           # All agent definitions
├── commands/*.md         # All command definitions
├── skills/**/*           # All skill files
├── hooks/**/*            # All hook scripts
├── README.md             # SDK documentation
└── rules/
    ├── language.md
    ├── git-commit-format.md
    ├── issue-pr-format.md
    ├── milestone-guide.md
    ├── file-movement-protocol.md
    ├── github-comment-attribution.md
    ├── project-board-integration.md
    └── summary-preferences.md
```

### User-Owned Files (Never Touched)

```
.claude/rules/
├── custom-project-rules.md
└── custom-workflows.md
```

### Templated Files (Prompt User)

```
.claude/
├── CLAUDE.md               # Contains ${PROJECT_NAME}
├── git-tags.md             # Contains ${PROJECT_NAME}
├── settings.json           # Contains project paths
└── PROJECT_CONFIG.md       # May have user edits
```

## Update Algorithm

### High-Level Flow

1. Validate `.claude/` exists
2. Create timestamped backup to `.claude.backup.YYYYMMDD-HHMMSS/`
3. Update SDK-owned directories (agents, commands, skills, hooks)
4. Selectively update rules/ (skip user-owned files)
5. Handle templated files (prompt for changes)
6. Report orphaned files
7. Print summary

### Implementation Steps

**Step 1: Validate Target**

```bash
validate_update_target() {
    if [ ! -d "$MASTER_PROJ/.claude" ]; then
        log_error "No .claude/ directory found"
        log_error "Use 'init' or 'port' mode first"
        exit 1
    fi
}
```

**Step 2: Create Backup**

```bash
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$MASTER_PROJ/.claude.backup.$timestamp"

    # Handle timestamp collision
    while [ -d "$backup_dir" ]; do
        backup_dir="${backup_dir}-${RANDOM}"
    done

    cp -r "$MASTER_PROJ/.claude" "$backup_dir" || {
        log_error "Failed to create backup"
        exit 1
    }

    log_success "Backup created: $backup_dir"
}
```

**Step 3: Update SDK-Owned Directories**

```bash
update_sdk_directories() {
    local dirs=("agents" "commands" "skills" "hooks")

    for dir in "${dirs[@]}"; do
        rm -rf "$MASTER_PROJ/.claude/$dir"
        cp -r "$AGENTIZE_SDK/claude/$dir" "$MASTER_PROJ/.claude/$dir"
        log_success "Updated $dir/"
    done

    cp "$AGENTIZE_SDK/claude/README.md" "$MASTER_PROJ/.claude/README.md"
    log_success "Updated README.md"
}
```

**Step 4: Update SDK-Owned Rules Selectively**

```bash
update_sdk_rules() {
    local sdk_rules=(
        "language.md"
        "git-commit-format.md"
        "issue-pr-format.md"
        "milestone-guide.md"
        "file-movement-protocol.md"
        "github-comment-attribution.md"
        "project-board-integration.md"
        "summary-preferences.md"
    )

    for rule in "${sdk_rules[@]}"; do
        cp "$AGENTIZE_SDK/claude/rules/$rule" \
           "$MASTER_PROJ/.claude/rules/$rule"
    done

    log_success "Updated rules/"
    log_info "Preserved: custom-project-rules.md, custom-workflows.md"
}
```

**Step 5: Handle Templated Files**

```bash
handle_templated_files() {
    local templates=("CLAUDE.md" "git-tags.md" "settings.json")

    for template in "${templates[@]}"; do
        local sdk_file="$AGENTIZE_SDK/claude/templates/${template}"
        local target_file="$MASTER_PROJ/.claude/$template"

        if ! diff -q "$sdk_file" "$target_file" >/dev/null 2>&1; then
            while true; do
                echo "Template file changed: $template"
                echo "  [s]kip  [o]verwrite  [d]iff  [q]uit"
                read -p "Choice: " choice

                case "$choice" in
                    s|S) log_info "Skipped: $template"; break ;;
                    o|O) cp "$sdk_file" "$target_file"
                         log_success "Overwrote: $template"; break ;;
                    d|D) diff -u "$target_file" "$sdk_file" | head -50 ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice" ;;
                esac
            done
        fi
    done
}
```

**Step 6: Report Orphaned Files**

```bash
report_orphaned_files() {
    local orphans=()

    while IFS= read -r file; do
        local rel_path="${file#$MASTER_PROJ/.claude/}"
        local sdk_path="$AGENTIZE_SDK/claude/$rel_path"

        # Skip user-owned files
        [[ "$rel_path" == "rules/custom-project-rules.md" ]] && continue
        [[ "$rel_path" == "rules/custom-workflows.md" ]] && continue

        [ ! -f "$sdk_path" ] && orphans+=("$rel_path")
    done < <(find "$MASTER_PROJ/.claude" -type f)

    if [ ${#orphans[@]} -gt 0 ]; then
        log_warning "Orphaned files (not in SDK):"
        for orphan in "${orphans[@]}"; do
            echo "  - $orphan"
        done
        log_info "These files were NOT deleted"
    fi
}
```

## Backup and Rollback Strategy

**Backup Location**: `.claude.backup.YYYYMMDD-HHMMSS/` in target project root

**Rollback Procedure**:
```bash
rm -rf .claude
mv .claude.backup.YYYYMMDD-HHMMSS .claude
```

**Backup Retention**: Not auto-deleted; users should review and delete manually when satisfied.

## Error Handling

| Error | Response |
|-------|----------|
| No .claude/ directory | Error: "No Agentize installation found. Use init or port mode first." Exit 1 |
| Backup creation fails | Error with details. Exit 1. No modifications made. |
| User interrupts (Ctrl-C) | Graceful exit. Backup exists for manual recovery. |
| File copy fails | Error logged. Backup preserved. Recommend rollback. |

## Edge Cases

1. **Modified SDK-Owned Files**: User modifies `agents/general-purpose.md` (SDK-owned) → File is replaced during update
2. **User-Created Agents**: User creates `.claude/agents/my-agent.md` → Reported as orphaned, NOT deleted
3. **Backup Directory Collision**: Timestamp collision → Append random suffix
4. **Partial Update Failure**: Update fails after modifying some files → Error logged, backup preserved, recommend rollback

## Testing Strategy

**Integration Tests**:
1. Init → modify user files → update → verify SDK files updated, user files preserved
2. Init → modify CLAUDE.md → update → verify prompt appears, choice respected
3. Init → add custom file → update → verify reported as orphaned, not deleted
4. Update → rollback → verify original state restored

**Regression Tests**: Ensure update mode doesn't break init/port modes.

## Future Enhancements

1. **Dry-run mode**: Show what would change without modifying (Priority 1)
2. **Orphan cleanup flag**: Prompt to delete orphaned files (Priority 1)
3. **Version tracking**: Store SDK version in `.claude/.agentize-version` (Priority 2)
4. **Non-interactive mode**: Auto-accept prompts for CI/CD (Priority 2)
5. **Component-level updates**: Update only agents, rules, etc. (Priority 2)

## References

- Draft design: `docs/draft/agentize-update-mode-20251221-095709.md`
- Current installation: `scripts/install.sh`
- [Claude Code Settings](https://code.claude.com/docs/en/settings) - Precedence hierarchy
- [Chezmoi](https://www.chezmoi.io/) - Template-based configuration management
- [AI SDK 5.0 Migration Guide](https://ai-sdk.dev/docs/migration-guides/migration-guide-5-0) - SDK update best practices

---

**Document Version**: 1.0
**Last Updated**: 2025-12-21
**Maintainer**: @were
