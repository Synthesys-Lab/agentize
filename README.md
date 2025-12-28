# AI-powered SDK for Software Development

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/SyntheSys-Lab/agentize.git
```
2. Set up the shell functions:

   **Option A: Generate local setup script (recommended for development)**
   ```bash
   make env-script
   source setup.sh
   ```
   This creates a `setup.sh` with the hardcoded repo path. Add `source /path/to/agentize/setup.sh` to your shell RC file for persistence.

   **Option B: Manual setup**
   Add to `~/.bashrc` or `~/.zshrc`:
   ```bash
   export AGENTIZE_HOME="/path/to/agentize"
   source "$AGENTIZE_HOME/scripts/wt-cli.sh"
   source "$AGENTIZE_HOME/scripts/lol-cli.sh"
   ```

3. Initialize a new project:
```bash
lol init --name your_project_name --lang c --path /path/to/your/project
```

This creates an initial SDK structure in the specified project path. Use `lol --help` to see all available options.

## Core Phylosophy

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

## Cross-Project Shell Functions

Agentize provides shell functions that work from any directory:
- `wt` - Manage worktrees (spawn, list, remove, prune)
- `lol` - Initialize and update SDK projects (init, update)

### Setup

**Option 1: Generate local setup script (recommended)**
```bash
make env-script
source setup.sh
# Add 'source /path/to/agentize/setup.sh' to your shell RC for persistence
```

**Option 2: Manual setup**
Add to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
export AGENTIZE_HOME="/path/to/agentize"
source "$AGENTIZE_HOME/scripts/wt-cli.sh"
source "$AGENTIZE_HOME/scripts/lol-cli.sh"
```

### Worktree Management (`wt`)

Manage git worktrees from any directory:

```bash
wt spawn 42              # Create worktree for issue #42
wt list                  # List all worktrees
wt remove 42             # Remove worktree for issue #42
wt prune                 # Clean up stale worktree metadata
```

Worktrees are always created under `$AGENTIZE_HOME/trees/`, regardless of your current directory.

### SDK Project Management (`lol`)

Ergonomic commands for initializing and updating SDK projects:

**Initialize a new project:**

```bash
lol init --name my-project --lang python --path /path/to/project
```

**Update an existing project:**

From project root or any subdirectory:
```bash
lol update
```

Or specify explicit path:
```bash
lol update --path /path/to/project
```

The `update` command finds the nearest `.claude/` directory by traversing parent directories, making it convenient to use from anywhere within your project.

**Available options:**
- `--name <name>` - Project name (required for init)
- `--lang <lang>` - Programming language: c, cxx, python (required for init)
- `--path <path>` - Project path (optional, defaults to current directory)
- `--source <path>` - Source code path relative to project root (optional)

Use `lol --help` for complete documentation.

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
