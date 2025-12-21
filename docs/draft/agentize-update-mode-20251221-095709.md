# Design Draft: Agentize SDK Update Mode

**Created**: 2025-12-21 09:57:09
**Status**: Draft - Brainstorming Complete

## Executive Summary

This design adds an "update" mode to the Agentize SDK Makefile (`AGENTIZE_MODE=update`) to refresh `.claude/` configurations in previously-initialized target repositories. The design uses a selective copy strategy with explicit file ownership categories: SDK-owned files are replaced, user-owned files are preserved, and templated files prompt for confirmation.

## Problem Statement

Currently, Agentize supports two installation modes:
- **init**: Full project initialization (creates Makefile, docs/, README, .claude/)
- **port**: Minimal installation for existing projects (only installs .claude/)

There is no mechanism to update the `.claude/` configuration when the Agentize SDK evolves. Users who want new agents, commands, or rules must either:
1. Manually copy files (error-prone, tedious)
2. Delete `.claude/` and re-run port (loses customizations)
3. Track changes in Agentize and apply manually (impractical)

## Design Decision Record

### Key Decisions Made

| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Sync strategy | Selective copy with ownership categories | Non-breaking, works with current directory structure, no external dependencies | Three-way merge, submodules, symlinks, layered directories |
| Claude Code compatibility | Single .claude/ directory | Claude Code does NOT support layered loading or merging multiple directories (verified via official docs) | Layered base/overrides architecture |
| User file identification | Explicit file list | Simple, predictable, no manifest file needed | Manifest with checksums, naming convention |
| Templated file handling | Prompt for confirmation | Templates contain project-specific values that cannot be auto-merged | Always skip, always overwrite, three-way merge |
| Deletion semantics | Report but do not auto-delete | Safety first - user decides | Auto-delete orphaned files |

### Critical Issues Resolved

1. **Claude Code Multi-Directory Loading**: RESOLVED - Claude Code uses precedence hierarchy, not merging. Proposals B, C, D (layered/submodule/symlink) would require flattening logic that adds complexity without benefit. Selective copy is the simplest viable approach.

2. **File Ownership Model**: RESOLVED - Files are explicitly categorized:
   - SDK-owned: agents/, commands/, rules/ (except custom-*), skills/, hooks/, README.md
   - User-owned: custom-project-rules.md, custom-workflows.md
   - Templated: CLAUDE.md, git-tags.md, settings.json, PROJECT_CONFIG.md

3. **Templated Files**: RESOLVED - Cannot be auto-merged due to ${PROJECT_NAME} substitution. Update mode will detect changes and prompt user with options: skip, overwrite, or show diff.

### Acknowledged Tradeoffs

1. **No Three-Way Merge**: We sacrifice "intelligent" merge capability for simplicity. Users who heavily modify SDK-owned files will lose changes on update. Mitigation: Documentation warns users to use custom-project-rules.md for customizations.

2. **No Version Pinning**: Updates always apply latest SDK state. Mitigation: Users can use git tags/branches in their Agentize clone if they need version control.

3. **Manual Conflict Resolution**: Templated files require user decision. Mitigation: Clear prompts with diff preview option.

## Design Specification

### Overview

Add `AGENTIZE_MODE=update` to the Makefile and corresponding logic in `install.sh`. The update mode:
1. Validates target has existing `.claude/` directory
2. Categorizes files by ownership
3. Updates SDK-owned files (add/replace)
4. Preserves user-owned files
5. Prompts for templated files
6. Reports summary of changes

### File Ownership Categories

```
SDK-OWNED (always update):
.claude/
├── agents/*.md              # All agent definitions
├── commands/*.md            # All command definitions
├── skills/**/*              # All skill files
├── hooks/**/*               # All hook scripts
├── README.md                # SDK documentation
└── rules/
    ├── language.md
    ├── git-commit-format.md
    ├── issue-pr-format.md
    ├── milestone-guide.md
    ├── file-movement-protocol.md
    ├── github-comment-attribution.md
    ├── github-workflows-readme-sync.md
    ├── project-board-integration.md
    ├── documentation-guidelines.md
    └── summary-preferences.md

USER-OWNED (never update):
.claude/rules/
├── custom-project-rules.md
└── custom-workflows.md

TEMPLATED (prompt user):
.claude/
├── CLAUDE.md               # Contains ${PROJECT_NAME}
├── git-tags.md             # Contains ${PROJECT_NAME}
├── settings.json           # Contains project paths
└── PROJECT_CONFIG.md       # May have user edits
```

### Update Algorithm

```bash
update_mode() {
    # 1. Validate .claude/ exists
    if [ ! -d "$TARGET/.claude" ]; then
        error "No .claude/ directory found. Use 'init' or 'port' mode first."
        exit 1
    fi

    # 2. Create backup
    backup_dir="$TARGET/.claude.backup.$(date +%Y%m%d%H%M%S)"
    cp -r "$TARGET/.claude" "$backup_dir"
    log "Backup created: $backup_dir"

    # 3. Update SDK-owned directories (replace entirely)
    for dir in agents commands skills hooks; do
        rm -rf "$TARGET/.claude/$dir"
        cp -r "$SDK/.claude/$dir" "$TARGET/.claude/$dir"
        log "Updated: $dir/"
    done

    # 4. Update SDK-owned rules (selective)
    SDK_RULES=(
        "language.md"
        "git-commit-format.md"
        "issue-pr-format.md"
        "milestone-guide.md"
        "file-movement-protocol.md"
        "github-comment-attribution.md"
        "github-workflows-readme-sync.md"
        "project-board-integration.md"
        "documentation-guidelines.md"
        "summary-preferences.md"
    )
    for rule in "${SDK_RULES[@]}"; do
        cp "$SDK/claude/rules/$rule" "$TARGET/.claude/rules/$rule"
        log "Updated: rules/$rule"
    done

    # 5. Preserve user-owned files (no action needed)
    log "Preserved: rules/custom-project-rules.md"
    log "Preserved: rules/custom-workflows.md"

    # 6. Handle templated files (prompt)
    for template in CLAUDE.md git-tags.md settings.json PROJECT_CONFIG.md; do
        if file_changed "$SDK/claude/templates/$template" "$TARGET/.claude/$template"; then
            prompt_template_update "$template"
        fi
    done

    # 7. Handle new files (add)
    # Check for new rules, agents, commands not in target

    # 8. Report orphaned files (files in target not in SDK)
    report_orphaned_files

    # 9. Summary
    print_update_summary
}
```

### User Interface

```bash
# Invoke update mode
make agentize AGENTIZE_MASTER_PROJ=../my-project AGENTIZE_MODE=update

# Expected output
┌─────────────────────────────────────────────────────────────┐
│  Updating Agentize in ../my-project
└─────────────────────────────────────────────────────────────┘

i  Creating backup: .claude.backup.20251221095709
OK  Backup created

i  Updating SDK-owned components...
OK  Updated agents/ (15 files)
OK  Updated commands/ (8 files)
OK  Updated rules/ (10 files)
OK  Updated skills/ (4 directories)
OK  Updated hooks/ (2 files)

i  Preserved user-owned files:
   - rules/custom-project-rules.md
   - rules/custom-workflows.md

i  Templated files with changes:
   CLAUDE.md has SDK changes. Options:
   [s]kip  [o]verwrite  [d]iff  [q]uit: d

   --- a/.claude/CLAUDE.md
   +++ b/.claude/CLAUDE.md
   @@ -42,6 +42,8 @@
    - `milestone-guide.md` - Multi-session milestone framework
    - `file-movement-protocol.md` - Safe file rename/move protocol
    - `git-commit-format.md` - **MUST check before any `git commit`**
   +- `project-board-integration.md` - GitHub Project integration
   +- `github-comment-attribution.md` - AI comment attribution

   [s]kip  [o]verwrite  [d]iff  [q]uit: s
   OK  Skipped: CLAUDE.md

i  Orphaned files (in target but not in SDK):
   - rules/my-custom-rule.md
   These files were NOT deleted. Review manually if needed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Update Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary:
  Updated:   35 files
  Preserved: 2 files
  Skipped:   1 file (templated)
  Orphaned:  1 file (not deleted)
  Backup:    .claude.backup.20251221095709

To undo: rm -rf .claude && mv .claude.backup.20251221095709 .claude
```

### Key Interfaces

**Makefile Changes:**
```makefile
# Existing line (line 33 of Makefile):
#   @echo "  AGENTIZE_MODE=<init|port>      Installation mode (default: init)"
# Change to:
#   @echo "  AGENTIZE_MODE=<init|port|update>  Installation mode (default: init)"

# Existing line (line 38-39):
# Modes:
#   init  - Initialize new project (creates Makefile, docs/, README, etc.)
#   port  - Port to existing project (only installs .claude/ configs)
# Add:
#   update - Update existing .claude/ to latest SDK (preserves customizations)
```

**install.sh Changes:**
```bash
# Existing validation (line 133):
#     if [ "$MODE" != "init" ] && [ "$MODE" != "port" ]; then
# Change to:
#     if [ "$MODE" != "init" ] && [ "$MODE" != "port" ] && [ "$MODE" != "update" ]; then

# Add new function update_components() after line 204

# Modify main() to call update_components() when MODE=update
```

### Constraints

1. **Requires existing .claude/**: Update mode validates that `.claude/` exists before proceeding
2. **Creates backup**: Always creates timestamped backup before modifying
3. **Preserves user files**: custom-project-rules.md and custom-workflows.md are NEVER touched
4. **Reports orphans**: Files in target but not in SDK are reported but not deleted
5. **Requires user input**: Templated files require interactive decision

## Research References

### Internal References

| File | Relevance |
|------|-----------|
| `/Users/were/repos/playground/agentize/scripts/install.sh` | Current installation logic to extend |
| `/Users/were/repos/playground/agentize/Makefile` | Entry point for update mode |
| `/Users/were/repos/playground/agentize/claude/README.md` | Documents user-owned vs SDK-owned files |
| `/Users/were/repos/playground/agentize/claude/CUSTOMIZATION_GUIDE.md` | Customization patterns to preserve |

### External References

| Source | Key Insight |
|--------|-------------|
| [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) | Claude Code does NOT merge multiple .claude/ directories; uses strict precedence |
| [Chezmoi dotfile manager](https://www.chezmoi.io/why-use-chezmoi/) | Inspiration for manifest-based tracking (not used, but informed design) |
| [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) | Symlink approach considered but rejected for portability |

## Open Questions

1. **Should we support --dry-run?** Would be helpful but adds implementation complexity. Consider for v2.
2. **Should orphaned files be deletable with a flag?** E.g., `AGENTIZE_CLEAN_ORPHANS=1`. Consider for v2.
3. **Should we track SDK version?** A `.claude/.agentize-version` file could enable smarter updates. Consider for v2.

## Next Steps

This design is ready for:
1. Implementation in `/Users/were/repos/playground/agentize/scripts/install.sh`
2. Documentation update in `/Users/were/repos/playground/agentize/README.md`
3. Help text update in `/Users/were/repos/playground/agentize/Makefile`

---

*This draft was created through a three-stage brainstorming process: creative proposal, critical review, and independent synthesis.*
