# Tutorial 00: Initialize Your Project

**Read time: 3-5 minutes**

This tutorial shows you how to set up the Agentize framework in your project.

## Three Ways to Get Started

### 1. Create a New Project with Agentize

For a fresh project starting with the Agentize framework:

```bash
make agentize \
   AGENTIZE_PROJECT_NAME="my_project" \
   AGENTIZE_PROJECT_PATH="/path/to/new/project" \
   AGENTIZE_PROJECT_LANG="c" \
   AGENTIZE_MODE="init"
```

This creates the initial SDK structure with:
- `claude/` directory containing agent rules, skills, and commands
- `.claude/` symlink pointing to `claude/` for Claude Code integration
- Basic project structure and configuration

**Available languages**: `c`, `cxx`, `python` (see `docs/options.md` for more)

### 2. Import to/Update for an Existing Project

To add Agentize to your existing codebase or update the framework rules:

```bash
make agentize \
   AGENTIZE_PROJECT_NAME="existing_project" \
   AGENTIZE_PROJECT_PATH="/path/to/existing/project" \
   AGENTIZE_PROJECT_LANG="python" \
   AGENTIZE_MODE="update"
```

This mode:
- Creates `claude/` directory with core rules (if not present)
- Sets up `.claude/` symlink
- Leaves your existing code untouched
- Updates core framework files (skills, commands, agents)
- Preserves your custom extensions and modifications
- Merges new features from the framework

Use this for both:
- **Initial import**: Adding Agentize to an existing project for the first time
- **Framework updates**: Syncing latest Agentize rules while keeping your customizations

## What Gets Created

After initialization, your project will have:

```
your-project/
├── claude/                    # AI agent configuration
│   ├── agents/               # Specialized agent definitions
│   ├── commands/             # User-invocable commands (/command-name)
│   └── skills/               # Reusable skill implementations
├── .claude/                  # Symlink to claude/ (required by Claude Code)
├── docs/                     # Documentation (if you follow our conventions)
└── [your existing code]      # Unchanged
```

## Verify Installation

After setup, verify Claude Code recognizes your configuration:

```bash
# In your project directory with Claude Code
/help
```

You should see your custom commands listed (like `/issue-to-impl`, `/code-review`, etc.).

## Customizing Git Commit Tags (Optional)

Feel free to edit `docs/git-msg-tags.md` - the current tags are for the Agentize project itself. You can customize these tags to fulfill your project's module requirements.

For example, you might add project-specific tags like:
```markdown
- `api`: API changes
- `ui`: User interface updates
- `perf`: Performance improvements
```

The AI will use these tags when creating commits and issues. This is particularly useful in Tutorial 01 when creating [plan] issues.

## Next Steps

Once initialized:
- **Tutorial 01**: Learn how to create implementation plans with `/plan-an-issue` (uses the git tags you just customized)
- **Tutorial 02**: Learn the full development workflow with `/issue-to-impl`
- **Tutorial 03**: Scale up with parallel development workflows

## Configuration Options

For detailed configuration options (language settings, modes, paths):
- See `docs/options.md` for all available make variables
- See `README.md` for architecture overview

## Common Paths

After initialization, key directories are:
- Commands you can run: `claude/commands/*.md`
- Skills that power commands: `claude/skills/*/SKILL.md`
- Agent definitions: `claude/agents/*.md`
- Git commit standards: `docs/git-msg-tags.md`
