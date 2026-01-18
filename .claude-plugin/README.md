# Claude Code Plugin

This directory contains the Agentize Claude Code plugin, which provides AI-powered development workflows for planning, implementation, and code review.

## Purpose

The `.claude-plugin` directory is the root of a Claude Code plugin that extends Claude's capabilities with specialized commands, skills, agents, and hooks. It enables automated development workflows while maintaining flexibility for both handsoff automation and interactive use.

## Structure

```
.claude-plugin/
├── marketplace.json        # Plugin manifest and metadata
├── commands/               # User-invocable commands (slash commands)
├── skills/                 # Reusable workflow implementations
├── agents/                 # Specialized AI agents for specific tasks
├── hooks/                  # Lifecycle event handlers
└── lib/                    # Shared Python libraries
```

### Components

#### marketplace.json

Plugin manifest defining metadata:
- Plugin name, version, and description
- Author and license information
- Repository URL and homepage
- Plugin category and keywords
- Strict mode setting (currently `false` for flexibility)

#### commands/

User-facing slash commands that can be invoked in Claude Code. Each command is defined in a markdown file with frontmatter specifying:
- Command name and description
- Argument hints (for user guidance)
- Implementation (typically invokes skills)

**Available commands:**
- `/make-a-plan` - Create comprehensive implementation plans
- `/ultra-planner` - Multi-agent debate-based planning workflow
- `/issue-to-impl` - Complete development cycle from issue to implementation
- `/code-review` - Automated code review with quality checks
- `/pull-request` - Generate PR descriptions and manage pull requests
- `/git-commit` - Smart commit message generation
- `/setup-viewboard` - Initialize GitHub project boards
- `/sync-master` - Synchronize branches with main/master
- `/plan-to-issue` - Convert plans to GitHub issues
- `/agent-review` - Review agent configurations

See individual command files in `commands/` for detailed usage.

#### skills/

Reusable workflow implementations that can be invoked by commands or referenced by agents. Skills are modular, lightweight, and focused on specific tasks.

**Core skills:**
- `plan-guideline` - Comprehensive planning framework
- `document-guideline` - Documentation standards
- `commit-msg` - Commit message generation
- `open-issue` - GitHub issue creation
- `open-pr` - Pull request creation
- `milestone` - Incremental development with progress tracking
- `fork-dev-branch` - Development branch management
- `move-a-file` - File refactoring with reference updates
- `doc-architect` - Documentation checklist generation
- `review-standard` - Code review standards
- `shell-script-review` - Shell script quality checks
- `debug-report` - Debugging assistance
- `external-consensus` - External validation workflows

See `skills/CLAUDE.md` for skill development guidelines.

#### agents/

Specialized AI agents configured for specific planning and analysis tasks. Each agent has:
- Custom system prompts and instructions
- Specific tool access permissions
- Model selection (e.g., Opus for research-heavy tasks)
- Skill references for reusable workflows

**Available agents:**
- `bold-proposer` - Research SOTA solutions and propose innovative approaches
- `proposal-critique` - Critical analysis of implementation proposals
- `proposal-reducer` - Consolidate multiple proposals into actionable plans
- `planner-lite` - Lightweight planning for simpler tasks
- `understander` - Deep codebase comprehension
- `code-quality-reviewer` - Code quality and standards enforcement

Agents are typically invoked by commands like `/ultra-planner` that orchestrate multi-agent workflows.

#### hooks/

Lifecycle event handlers that execute automatically at specific points in the Claude Code workflow. Hooks enable automation without explicit user commands.

**Event handlers:**
- `session-init.sh` - Initialize project environment on session start
- `pre-tool-use.py` - Permission evaluation before tool execution
- `post-edit.sh` - Post-processing after file edits
- `user-prompt-submit.py` - Workflow detection and state initialization
- `stop.py` - Auto-continuation for handsoff workflows

See `hooks/README.md` for detailed hook documentation.

#### lib/

Shared Python libraries used by hooks, skills, and external integrations. All reusable code lives here to maintain separation between entry points (hooks) and implementation (lib).

**Modules:**
- `permission/` - Tool permission evaluation with rule matching and LLM fallback
- `workflow.py` - Workflow detection and continuation prompts for handsoff mode
- `logger.py` - Debug logging utilities
- `telegram_utils.py` - Telegram Bot API helpers

See `lib/README.md` for library architecture and usage patterns.

## Usage

### As a Claude Code Plugin

1. **Install the plugin** in your project by referencing this directory:
   ```bash
   # In your project's .claude/settings.json
   {
     "plugins": [
       {
         "path": "path/to/agentize/.claude-plugin"
       }
     ]
   }
   ```

2. **Use commands** via Claude Code's slash command interface:
   ```
   /ultra-planner requirements for new feature
   /issue-to-impl 123
   /code-review
   ```

3. **Hooks execute automatically** based on lifecycle events configured in `.claude/settings.json`

### Development

When developing new plugin components:

1. **Commands** - Define in `commands/` as markdown with frontmatter
   - Keep commands as thin wrappers around skills
   - Focus on user interface and argument parsing

2. **Skills** - Implement in `skills/` as reusable workflows
   - Follow guidelines in `skills/CLAUDE.md`
   - Skills cannot invoke other skills (leaf nodes only)
   - Include few-shot examples sparingly

3. **Agents** - Configure in `agents/` for specialized tasks
   - Use appropriate model for complexity (Haiku/Sonnet/Opus)
   - Reference relevant skills for consistency
   - Provide clear role definition and workflow steps

4. **Hooks** - Add in `hooks/` for automation
   - Keep hooks simple, delegate to `lib/` for complex logic
   - Fail silently to avoid interrupting user workflow
   - Document interface in companion `.md` file

5. **Libraries** - Add to `lib/` for shared code
   - Maintain dependency direction: hooks → lib
   - Use proper import patterns (see `lib/README.md`)

## Integration with Agentize SDK

This plugin is part of the broader Agentize SDK ecosystem:

- **CLI tools** (`src/cli/`) complement plugin commands for standalone usage
- **Python modules** (`python/agentize/`) provide server-side functionality
- **Documentation** (`docs/`) explains workflows and design decisions
- **Templates** (`templates/`) provide scaffolding for new projects

The plugin can be used independently or as part of the full SDK workflow.

## Configuration

### Environment Variables

- `AGENTIZE_HOME` - Project root directory (set by `session-init.sh`)
- `HANDSOFF_DEBUG` - Enable debug logging for permission and workflow hooks
- `GITHUB_TOKEN` - GitHub API authentication (for issue/PR commands)

### Handsoff Mode

Handsoff mode enables fully automated workflows with minimal user intervention. Configure via:

1. **Permission rules** in `lib/permission/rules.py`
2. **Workflow continuation** in `lib/workflow.py`
3. **Hook configuration** in `.claude/settings.json`

See `docs/feat/core/handsoff.md` for detailed setup.

## Testing

The plugin components are tested as part of the SDK test suite:

```bash
# Run all tests
make test

# Test specific shells
TEST_SHELLS="bash zsh" make test
```

Individual skills and commands are validated through dogfooding during actual development workflows.

## Plugin Metadata

- **Name**: agentize
- **Version**: 1.0.9
- **Author**: Synthesys-Lab
- **License**: MIT
- **Homepage**: https://github.com/Synthesys-Lab/agentize
- **Category**: development
- **Keywords**: workflow, tdd, sdd, handsoff

## References

- [Claude Code Plugin Documentation](https://agentskills.io/)
- [Agentize SDK README](../README.md)
- [Development Workflows](../docs/feat/core/)
- [Tutorial: Initialize Your Project](../docs/tutorial/00-initialize.md)
