# AI-powered SDK for Software Development

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/SyntheSys-Lab/agentize.git
```
2. Set up the shell functions:
```bash
make setup
source setup.sh
```

3. Initialize a new project:
```bash
lol init --name your_project_name --lang c --path /path/to/your/project # For your new project
lol update --path /path/to/your/existing/project # For your existing project updating the rules
```
This creates an initial SDK structure in the specified project path. Use `lol --help` to see all available options.

**Available options:**
- `--name <name>` - Project name (required for init)
- `--lang <lang>` - Programming language: c, cxx, python (required for init)
- `--path <path>` - Project path (optional, defaults to current directory)
- `--source <path>` - Source code path relative to project root (optional for C/C++ projects)

Use `lol --help` for complete documentation.


> In case you are curious about why we name the CLI `lol`, it is from a famous saying from Alan
> Perlis: _When someone says, "I want a programming language in which I need only say what I want done,"
> give him a `lol`lipop._

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

- [Ultra Planner Workflow](./docs/workflows/ultra-planner.md) - Multi-agent debate-based planning
- [Issue to Implementation Workflow](./docs/workflows/issue-to-implementation.md) - Complete development cycle

**Legend**: Red boxes represent user interventions (providing requirements, approving/rejecting results, starting sessions). Blue boxes represent automated AI steps.

## Tutorials

Learn Agentize in 15 minutes with our step-by-step tutorials (3-5 min each):

1. **[Initialize Your Project](./docs/tutorial/00-initialize.md)** - Set up Agentize in new or existing projects
2. **[Plan an Issue](./docs/tutorial/01-plan-an-issue.md)** - Create implementation plans and GitHub issues
3. **[Ultra Planner](./docs/tutorial/01b-ultra-planner.md)** - Multi-agent debate-based planning for complex features
4. **[Issue to Implementation](./docs/tutorial/02-issue-to-impl.md)** - Complete development cycle with `/issue-to-impl`, `/code-review`, and `/sync-master`
5. **[Advanced Usage](./docs/tutorial/03-advanced-usage.md)** - Scale up with parallel development workflows

## Per-Project Worktrees

Agentize also provides ergonomic shell functions for you to manage git worktrees so that you
can develop multiple features in parallel (refer to [Advanced Usage](./docs/tutorial/03-advanced-usage.md)
tutorial which already mentioned above for more details).

### Worktree Management (`wt`)

Manage git worktrees on a per-project basis using the bare repository pattern:

```bash
wt init                  # Initialize trees/ directory with trees/main/ worktree
wt main                  # Navigate to trees/main/ worktree
wt spawn 42              # Create worktree for issue #42 and auto-launch claude
wt spawn 42 --no-agent   # Create worktree without launching claude (for scripting)
wt list                  # List all worktrees
wt remove 42             # Remove worktree for issue #42 (also deletes branch)
wt remove 42 --keep-branch  # Remove worktree but keep the branch
wt prune                 # Clean up stale worktree metadata
```

`wt spawn` automatically launches claude in the new worktree when running interactively. Use `--no-agent` to disable auto-launch for scripting or testing.

**Bare Repository Pattern:**

After running `wt init`, your repository structure becomes:

```
repo-root/           # Coordination point (detached HEAD)
├── .git/
├── trees/
│   ├── main/        # Main branch worktree (created by wt init)
│   ├── issue-42-*/  # Feature branch worktrees (created by wt spawn)
│   └── issue-43-*/
```

The main repository becomes a coordination point while all development work happens
in worktrees under `trees/`. Use `wt main` to quickly navigate to the main branch worktree.

## Project Organization

```plaintext
agentize/
├── docs/                   # Document
│   ├── draft/              # Draft documents for local development
│   └── git-msg-tags.md     # Used by \commit-msg skill and command to write meaningful commit messages
├── scripts/                # Shell scripts and functions
│   ├── wt-cli.sh           # Cross-project wt shell function
│   ├── lol-cli.sh          # CLI wrapper functions
│   └── worktree.sh         # Core worktree management
├── templates/              # Templates for SDK generation
├── .claude/                # Core agent rules for Claude Code
├── tests/                  # Test cases
├── .gitignore              # Git ignore file
├── Makefile                # Build targets for testing and setup
└── README.md               # This readme file
```
