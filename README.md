# AI-powered SDK for Software Development

## Quick Start

### One-Command Install

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

Then add to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source $HOME/.agentize/setup.sh
```

See [docs/cli/install.md](./docs/cli/install.md) for installation options and troubleshooting.

**Upgrade:** Run `lol upgrade` to pull the latest changes.

### Manual Install

If you prefer manual setup:

```bash
# Clone the repository
git clone https://github.com/SyntheSys-Lab/agentize.git ~/.agentize

# Run setup
cd ~/.agentize
make setup
```

Then add to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source $HOME/.agentize/setup.sh
```

### Plugin Install (Claude Code)

For Claude Code users, install Agentize as a plugin:

```bash
# Development/testing: point to local directory
claude --plugin-dir /path/to/agentize

# From marketplace (once published)
/plugin install agentize@synthesys-lab
```

Plugin mode namespaces all commands with `agentize:` prefix (e.g., `/agentize:ultra-planner`).

See [docs/plugin-installation.md](./docs/plugin-installation.md) for details.

## Core Philosophy

1. Plan first, code later: Use AI to generate a detailed plan before writing any code.
   - Plan is put on Github Issues for tracking.
2. Build [skills](https://agentskills.io/).
   - Skills are modular reusable, formal, and lightweighted flow definitions.
   - This is something like C-style declaration and implementation separation.
     - `/commands` are declarations and interfaces for users to invoke skills.
     - `/skills` are implementations of the skills.
3. Bootstrapping via self-improvement: We use `.claude/` as our canonical rules
   directory. We use these rules to develop these rules further.
   - Top-down design: Start with a high-level view of the development flow.
   - Bottom-up implementation: Implement each aspect of the flow from bottom, and finally
     integrate them together.

### Workflow:

See our detailed workflow diagrams:

- [Ultra Planner Workflow](./docs/feat/core/ultra-planner.md) - Multi-agent debate-based planning
- [Issue to Implementation Workflow](./docs/feat/core/issue-to-impl.md) - Complete development cycle

**Legend**: Red boxes represent user interventions (providing requirements, approving/rejecting results, starting sessions). Blue boxes represent automated AI steps.

## Tutorials

Learn Agentize in 15 minutes with our step-by-step tutorials (3-5 min each):

1. **[Initialize Your Project](./docs/tutorial/00-initialize.md)** - Set up Agentize in new or existing projects
2. **[Plan an Issue](./docs/tutorial/01-plan-an-issue.md)** - Create implementation plans and GitHub issues
3. **[Ultra Planner](./docs/tutorial/01b-ultra-planner.md)** - Multi-agent debate-based planning for complex features
4. **[Issue to Implementation](./docs/tutorial/02-issue-to-impl.md)** - Complete development cycle with `/issue-to-impl`, `/code-review`, and `/sync-master`
5. **[Advanced Usage](./docs/tutorial/03-advanced-usage.md)** - Scale up with parallel development workflows

## Cross-Project Shell Functions

Agentize provides shell functions that work from any directory:
- `wt` - Manage worktrees in bare git repositories (spawn, list, remove, prune, purge)
- `lol` - SDK management utilities (upgrade, project, usage, serve, claude-clean)

For persistence, add `source /path/to/agentize/setup.sh` to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.).


General-purpose git worktree helper for **bare repositories**:

```bash
wt init                  # Initialize worktree environment (run once per bare repo)
wt goto main             # Change directory to main worktree
wt goto 42               # Change directory to issue-42 worktree
wt spawn 42              # Create issue-42 branch and worktree
wt list                  # List all worktrees
wt remove 42             # Remove worktree for issue #42
wt prune                 # Clean up stale worktree metadata
wt purge                 # Remove worktrees for closed GitHub issues
wt help                  # Display help information
```

**Bare repository requirement:** `wt` works with bare git repositories. Worktrees are created under `<bare-repo>/trees/`. See `docs/cli/wt.md` for migration guide.

### SDK Utilities (`lol`)

Ergonomic commands for SDK management:

```bash
lol upgrade              # Upgrade agentize installation
lol project --create     # Create GitHub Projects v2 board
lol project --associate  # Associate existing project board
lol usage                # Report Claude Code token usage
lol claude-clean         # Remove stale project entries
```

Use `lol --help` for complete documentation.

## Project Organization

```plaintext
agentize/
├── .claude-plugin/         # Plugin manifest (plugin.json)
├── commands/               # Claude Code commands
├── skills/                 # Claude Code skills
├── agents/                 # Claude Code agents
├── hooks/                  # Claude Code hooks
├── python/                 # Python modules (agentize.*)
├── docs/                   # Documentation
│   ├── plugin-installation.md  # Plugin installation guide
│   └── git-msg-tags.md     # Commit message conventions
├── src/cli/                # Source-first CLI libraries
│   ├── wt.sh               # Worktree CLI library
│   └── lol.sh              # SDK CLI library
├── scripts/                # Shell scripts and wrapper entrypoints
├── templates/              # Templates for SDK generation
├── tests/                  # Test cases
├── Makefile                # Build targets for testing and setup
└── README.md               # This readme file
```
