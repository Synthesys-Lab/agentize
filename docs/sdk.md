# SDK Structure and Creation

This document describes the file structure of SDKs created by the `lol` CLI and the behavior of initialization and update modes.

## Created SDK File Structure

When you run `lol init`, the following structure is created in your target project:

```
your-project/
├── .claude/                    # Claude Code configuration (DIRECTORY, not symlink!)
│   ├── settings.json          # Claude Code settings
│   ├── commands/              # Custom slash commands
│   │   └── commit-msg/
│   ├── skills/                # Agent skills
│   │   ├── commit-msg/
│   │   └── open-issue/
│   └── hooks/                 # Git and event hooks
├── CLAUDE.md                  # Project-specific instructions for Claude
├── docs/
│   └── git-msg-tags.md        # Git commit message tag definitions
├── src/                       # Source code (or custom path via AGENTIZE_SOURCE_PATH)
├── tests/                     # Test files
└── [language-specific files]  # Makefile, CMakeLists.txt, setup.sh, etc.
```

### Important: `.claude/` Directory Structure

**In the agentize project itself:**
- `.claude/` is the **canonical directory** containing all agent rules, skills, and commands
- This serves as the single source of truth for development

**In created SDK projects:**
- `.claude/` is an **independent directory** (copied from the agentize `.claude/`)
- This makes the SDK project standalone and independent
- The SDK can be modified without affecting the agentize repository

This is a crucial architectural difference that allows:
1. **Agentize development**: Changes to `.claude/` define the framework
2. **SDK independence**: Each created SDK has its own configuration that can be customized

## Initialization Mode (`init`)

### Behavior

The `init` mode creates a new SDK project from scratch. It validates directory state before proceeding:

| Directory State | Behavior |
|----------------|----------|
| Does not exist | Creates directory and initializes SDK ✓ |
| Exists and is empty | Initializes SDK in existing directory ✓ |
| Exists and is NOT empty | **Aborts with error** ✗ |

### Example

```bash
# Create new SDK in non-existent directory
lol init --name my_project --lang python --path /path/to/my_project

# Error: Will fail if directory exists and contains files
lol init --name my_project --lang python --path /existing/non-empty/dir
# Output: Error: Directory '/existing/non-empty/dir' exists and is not empty.
```

### What Gets Created

1. **Language template files** (from `templates/{language}/`)
   - Build system files (Makefile, CMakeLists.txt, etc.)
   - Source code structure
   - Test structure

2. **Claude Code configuration** (copied from `.claude/`)
   - Skills for git operations
   - Commands for development workflow
   - Settings and hooks

3. **Documentation**
   - `CLAUDE.md` from template (parameterized with project name)
   - `docs/git-msg-tags.md` from template (parameterized for language)

4. **Bootstrap script execution** (if present)
   - Renames directories (e.g., `project_name/` → `{your_project_name}/`)
   - Updates imports and references
   - Removes itself after completion

## Update Mode (`update`)

### Behavior

The `update` mode refreshes the Claude Code configuration (`.claude/`) while preserving your customizations.

| Directory State | Behavior |
|----------------|----------|
| Does not exist | **Aborts with error** ✗ |
| Exists but no `.claude/` directory | **Aborts with error** ✗ |
| Valid SDK structure | Updates `.claude/` and creates backup ✓ |

### Example

```bash
# Update existing SDK from project root or any subdirectory
lol update

# Or specify explicit path
lol update --path /path/to/my_project

# Error: Will fail if not a valid SDK
lol update --path /some/random/dir
# Output: Error: Directory '/some/random/dir' is not a valid SDK structure.
#         Missing '.claude/' directory.
```

### What Gets Updated

**Updated files:**
- `.claude/settings.json` - Latest Claude Code settings
- `.claude/commands/` - Updated slash commands
- `.claude/skills/` - Latest agent skills
- `.claude/hooks/` - Updated event hooks

**Preserved files:**
- `CLAUDE.md` - Your project-specific instructions
- `docs/git-msg-tags.md` - Your custom tag definitions
- All source code and project files

**Backup:**
- Previous `.claude/` is backed up to `.claude.backup/`
- Allows you to recover custom modifications if needed

## Directory Validation Rules

### Init Mode Validation

```bash
if directory exists:
    if directory is not empty:
        abort with error  # Prevents accidental overwrites
    else:
        proceed with initialization
else:
    create directory and proceed
```

### Update Mode Validation

```bash
if directory does not exist:
    abort with error  # Must be existing project

if .claude/ directory does not exist:
    abort with error  # Must be valid SDK structure

create backup .claude.backup/
update .claude/ with latest files
```

## Common Workflows

### Creating a New SDK

```bash
# 1. Initialize SDK for C project
lol init --name mylib --lang c --path $HOME/projects/mylib

# 2. Navigate to project
cd $HOME/projects/mylib

# 3. Start using Claude Code
claude code
```

### Updating SDK Configuration

```bash
# When agentize releases new skills or updates
cd /path/to/agentize
git pull origin main

# Update your SDK project from project root or any subdirectory
cd $HOME/projects/mylib
lol update

# Review changes
diff -r .claude .claude.backup  # See what changed

# If you had customizations, selectively restore them
cp .claude.backup/skills/my-custom-skill .claude/skills/
```

### Recovering from Failed Update

```bash
# If update didn't work as expected
cd /path/to/your/project
rm -rf .claude
mv .claude.backup .claude
```

## Best Practices

1. **Always use empty directories for init mode**
   - Prevents accidental file overwrites
   - Ensures clean SDK structure

2. **Review .claude.backup/ after updates**
   - Check for custom modifications you want to preserve
   - Understand what changed in the new version

3. **Keep CLAUDE.md and docs/ customized**
   - These files are preserved during updates
   - Document project-specific context here

4. **Use version control**
   - Commit your SDK project to git
   - Track changes to `.claude/` configuration
   - Easy to revert if needed

## Troubleshooting

### Error: Directory exists and is not empty

```
Error: Directory '/path/to/project' exists and is not empty.
Please use an empty directory or a non-existent path for init mode.
```

**Solution:** Either use a different path, or manually verify and delete contents if safe.

### Error: Not a valid SDK structure

```
Error: Directory '/path/to/project' is not a valid SDK structure.
Missing '.claude/' directory.
```

**Solution:** This directory was not created with the `lol` CLI. Use `lol init` instead.

### Error: Project path does not exist

```
Error: Project path '/path/to/project' does not exist.
Use AGENTIZE_MODE=init to create it.
```

**Solution:** Use `init` mode to create a new SDK, not `update` mode.
