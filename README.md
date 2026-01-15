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
2. **[Ultra Planner](./docs/tutorial/01-ultra-planner.md)** - Primary planning tutorial (recommended)
3. **[Plan an Issue](./docs/tutorial/01b-plan-an-issue.md)** - Legacy single-agent planning (deprecated)
4. **[Issue to Implementation](./docs/tutorial/02-issue-to-impl.md)** - Complete development cycle with `/issue-to-impl` and `/code-review`
5. **[Advanced Usage](./docs/tutorial/03-advanced-usage.md)** - Scale up with parallel development workflows

## Project Organization

```plaintext
agentize/
├── .claude-plugin/         # Plugin root (use with --plugin-dir)
│   ├── marketplace.json    # Plugin manifest
│   ├── commands/           # Claude Code commands
│   ├── skills/             # Claude Code skills
│   ├── agents/             # Claude Code agents
│   └── hooks/              # Claude Code hooks
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
