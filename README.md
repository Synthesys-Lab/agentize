# AI-powered SDK for Software Development

[![Tests](https://github.com/SyntheSys-Lab/agentize/actions/workflows/test.yml/badge.svg)](https://github.com/SyntheSys-Lab/agentize/actions/workflows/test.yml)

## Prerequisites

### Required Tools

- **Git** - Version control (checked during installation)
- **Make** - Build automation (checked during installation)
- **Bash** - Shell interpreter, version 3.2+ (checked during installation)
- **GitHub CLI (`gh`)** - Required for GitHub integration features
  - Install: https://cli.github.com/
  - Authenticate after installation: `gh auth login`
  - Used by: `/setup-viewboard`, `/open-issue`, `/open-pr`, GitHub workflow automation
- **Python 3.10+** - Required for permission automation module, otherwise you can have infinite `yes` to prompt!
  - Use Python `venv` or `anaconda` to manage a good Python release!
  - Requires **PyYAML** (`pip install pyyaml`) for YAML configuration parsing

### Recommended Libraries

- **Anthropic Python Library** - For custom AI integrations (optional)
  - Install: `pip install anthropic`
  - Note: Not required for core SDK functionality, but recommended if you plan to extend or customize AI-powered features

### Verification

After installing prerequisites, the installer will automatically verify `git`, `make`, and `bash` availability. GitHub CLI authentication can be verified with:

```bash
gh auth status
```

## Quick Start

Agentize is an AI-powered SDK that helps you build your software projects
using Claude Code powerfully. It is splitted into two main components:

1. **Claude Code Plugin**: Automatically registered during installation when `claude` CLI is available.
   See [Tutorial 00: Initialize Your Project](./docs/tutorial/00-initialize.md) for details.
2. **CLI Tool**: A source-first CLI tool to help you manage your projects using Agentize.
   See the commands below to install.

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

Then add to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source $HOME/.agentize/setup.sh
```

See [docs/feat/cli/install.md](./docs/feat/cli/install.md) for installation options and troubleshooting.

**Upgrade:** Run `lol upgrade` to pull the latest changes.

## Troubleshoot

If you encounter any issue during the usage. For example:
1. It asks you for permission on a really simple operation.
2. It fails to automatically continue on a session.

Enable debug mode in your `.agentize.local.yaml`:

```yaml
handsoff:
  debug: true
```

Then re-run the command. This will give you a detailed log in either
- `/path/to/your/project/.tmp/handsoff-debug.log` or
- `$HOME/.agentize/.tmp/handsoff-debug.log`
Paste your logs on issue for me (@were) to debug!

For further help, please visit our [troubleshooting guide](./docs/troubleshoot.md).

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
   - You already did this if you followed the Quick Start!
2. **[Ultra Planner](./docs/tutorial/01-ultra-planner.md)** - Primary planning tutorial (recommended)
3. **[Issue to Implementation](./docs/tutorial/02-issue-to-impl.md)** - Complete development cycle with `/issue-to-impl` and `/code-review`
4. **[Advanced Usage](./docs/tutorial/03-advanced-usage.md)** - Scale up with parallel development workflows

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
