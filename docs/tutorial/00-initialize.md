# Tutorial 00: Initialize Your Project

**Read time: 3-5 minutes**

This tutorial shows you how to set up the Agentize framework in your project.

## Getting Started

After installing Agentize (see README.md), you can start using its features in your project.

### Setting Up Your Project

To use Agentize with your project:

1. **Create or navigate to your project directory**
2. **Initialize git** (if not already a git repository):
   ```bash
   git init
   ```
3. **Copy the `.claude/` directory** from the Agentize installation to your project:
   ```bash
   cp -r $AGENTIZE_HOME/.claude /path/to/your/project/
   ```

Alternatively, if you're using Agentize as a Claude Code plugin:
```bash
claude --plugin-dir /path/to/agentize
```

## What Gets Created

After setup, your project will have:

```
your-project/
├── .claude/                   # AI agent configuration
│   ├── agents/               # Specialized agent definitions
│   ├── commands/             # User-invocable commands (/command-name)
│   └── skills/               # Reusable skill implementations
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

For detailed configuration options:
- See `README.md` for architecture overview
- See `docs/architecture/` for design documentation

## Common Paths

After initialization, key directories are:
- Commands you can run: `.claude/commands/*.md`
- Skills that power commands: `.claude/skills/*/SKILL.md`
- Agent definitions: `.claude/agents/*.md`
- Git commit standards: `docs/git-msg-tags.md`
