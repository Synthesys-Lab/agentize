> **Looking for the CLI quickstart?** See [Tutorial 00: CLI Quickstart](./00-cli-quickstart.md) for the `wt clone` -> `lol plan` -> `lol impl` workflow.
>
> This tutorial covers Claude UI setup for users who prefer the `/ultra-planner` and `/issue-to-impl` slash commands.

# Tutorial 00a: Claude UI Setup

**Read time: 3-5 minutes**

This tutorial shows you how to set up the Agentize framework and Claude Code plugin in your project.
Use this path if you prefer the Claude UI slash commands for planning and implementation.

## Getting Started

After installing Agentize (see README.md), you can start using its features in your project.

## Installing Agentize

Agentize uses a single installer that handles both the CLI tools and the Claude Code plugin:

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

Then add to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source $HOME/.agentize/setup.sh
```

The installer automatically:
1. Clones the repository and runs setup
2. Registers the local Claude Code plugin marketplace (if `claude` CLI is available)
3. Installs the `agentize` plugin into Claude Code

If `claude` is not installed at the time of setup, you can register the plugin later by re-running the installer or manually:

```bash
claude plugin marketplace add "$HOME/.agentize"
claude plugin install agentize@agentize
```

## Verify Installation

After setup, verify the CLI entrypoints are available (the installer sets up both CLI and UI tooling):

```bash
lol plan --help
lol impl --help
```

Optional Claude UI check (see `docs/feat/core/ultra-planner.md` and `docs/feat/core/issue-to-impl.md`):

```bash
# In your project directory with Claude Code
/ultra-planner # Auto-completion shall pop up
/issue-to-impl
```

You should see your custom commands listed (like `/issue-to-impl`, `/code-review`, etc.).

## Preferred Project Organization

0. `docs/` is the key for the agent to understand your project.
1. Edit `docs/git-msg-tags.md` - the current tags are for the Agentize project itself. You can customize these tags to fulfill your project's module requirements.
For example, you might add project-specific tags like:
```markdown
- `api`: API changes
- `ui`: User interface updates
- `perf`: Performance improvements
```
2. It is preferred to have a `docs/architecture/` folder where you can document your project's architecture. This helps the agent understand your project better.


## Next Steps

Once initialized:
- **Tutorial 00**: If you prefer CLI onboarding, start with [Tutorial 00: CLI Quickstart](./00-cli-quickstart.md)
- **Tutorial 01**: Learn CLI planning with `lol plan --editor` (uses the git tags you just customized)
- **Tutorial 02**: Learn the CLI implementation loop with `lol impl <issue-no>`
- **Tutorial 03**: Scale up with parallel development workflows

## Configuration Options

For detailed configuration options:
- See `README.md` for architecture overview
- See `docs/architecture/` for design documentation
