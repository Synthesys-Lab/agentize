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

### 2. Import into an Existing Project

To add Agentize to your existing codebase:

```bash
make agentize \
   AGENTIZE_PROJECT_NAME="existing_project" \
   AGENTIZE_PROJECT_PATH="/path/to/existing/project" \
   AGENTIZE_PROJECT_LANG="python" \
   AGENTIZE_MODE="init"
```

The framework will:
- Create `claude/` directory with core rules
- Set up `.claude/` symlink
- Leave your existing code untouched
- Allow you to start using AI-powered development commands

### 3. Update Rules Without Losing Extensions

When Agentize framework updates, sync the latest rules while preserving your custom extensions:

```bash
make agentize \
   AGENTIZE_PROJECT_NAME="my_project" \
   AGENTIZE_PROJECT_PATH="/path/to/project" \
   AGENTIZE_MODE="update"
```

This mode:
- Updates core framework files (skills, commands, agents)
- Preserves your custom extensions and modifications
- Merges new features from the framework

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

Agentize uses standardized git commit tags for automatic commit message generation. The default tags are defined in `docs/git-msg-tags.md`:

- `feat`: New features
- `docs`: Documentation updates
- `bugfix`: Bug fixes
- `refactor`: Code refactoring
- `test`: Test-only changes
- `agent.skill`: Skill modifications
- `agent.command`: Command modifications

### Adding Your Own Tags

To add project-specific tags, edit `docs/git-msg-tags.md` in your project:

```markdown
## Tags

[... existing tags ...]

- `perf`: Performance improvements
- `security`: Security fixes
- `deps`: Dependency updates
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
