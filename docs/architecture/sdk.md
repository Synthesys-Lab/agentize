# SDK Structure

This document describes the file structure of SDK projects using the Agentize framework.

## SDK File Structure

A typical SDK project using Agentize has the following structure:

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
├── .git/hooks/
│   └── pre-commit             # Symlink to scripts/pre-commit (optional)
├── CLAUDE.md                  # Project-specific instructions for Claude
├── docs/
│   └── git-msg-tags.md        # Git commit message tag definitions
├── scripts/
│   └── pre-commit             # Pre-commit hook script
├── src/                       # Source code
├── tests/                     # Test files
└── [language-specific files]  # Makefile, CMakeLists.txt, setup.sh, etc.
```

### Important: `.claude/` Directory Structure

**In the agentize project itself:**
- `.claude/` is the **canonical directory** containing all agent rules, skills, and commands
- This serves as the single source of truth for development

**In SDK projects:**
- `.claude/` is an **independent directory** (copied from the agentize `.claude/`)
- This makes the SDK project standalone and independent
- The SDK can be modified without affecting the agentize repository

This is a crucial architectural difference that allows:
1. **Agentize development**: Changes to `.claude/` define the framework
2. **SDK independence**: Each SDK project has its own configuration that can be customized

## Setup

To set up an SDK project:

1. **Copy the `.claude/` directory** from the Agentize installation:
   ```bash
   cp -r $AGENTIZE_HOME/.claude /path/to/your/project/
   ```

2. **Copy documentation templates** (optional):
   ```bash
   cp $AGENTIZE_HOME/docs/git-msg-tags.md /path/to/your/project/docs/
   ```

3. **Copy pre-commit hook** (optional):
   ```bash
   cp $AGENTIZE_HOME/scripts/pre-commit /path/to/your/project/scripts/
   ln -s ../../scripts/pre-commit /path/to/your/project/.git/hooks/pre-commit
   ```

Alternatively, use Agentize as a Claude Code plugin:
```bash
claude --plugin-dir /path/to/agentize
```

## What Gets Created

1. **Claude Code configuration** (`.claude/`)
   - Skills for git operations
   - Commands for development workflow
   - Settings and hooks

2. **Documentation** (optional)
   - `CLAUDE.md` - Project-specific instructions
   - `docs/git-msg-tags.md` - Commit message tag definitions

3. **Pre-commit hook** (optional)
   - `scripts/pre-commit` - Hook script
   - `.git/hooks/pre-commit` - Symlink to hook script

## Common Workflows

### Setting Up a New SDK

```bash
# 1. Create project directory
mkdir ~/projects/mylib
cd ~/projects/mylib
git init

# 2. Copy SDK configuration
cp -r $AGENTIZE_HOME/.claude .

# 3. Start using Claude Code
claude
```

### Updating SDK Configuration

```bash
# When agentize releases new skills or updates
cd /path/to/agentize
git pull origin main

# Update your SDK project
cp -r $AGENTIZE_HOME/.claude /path/to/your/project/

# Review changes
git diff .claude/
```

## Best Practices

1. **Keep CLAUDE.md customized**
   - Document project-specific context here
   - This file guides Claude's behavior for your project

2. **Use version control**
   - Commit your SDK project to git
   - Track changes to `.claude/` configuration
   - Easy to revert if needed

3. **Customize git commit tags**
   - Edit `docs/git-msg-tags.md` for your project
   - Define project-specific tag categories
