# Development Architecture

This document outlines the development architecture of the project to
best fit in agentize's ecosystem. Although not strictly required, and
are some common software engineering practices, it is highly recommended
to follow, in local code structure, git, and GitHub usage.

All the `sdk` created by `lol apply --init` or `lol init` command shall follow this following architecture.


## Local Code Base

The code base shall follow the structure:

```plaintext
docs/                # High-level documentation files and design docs
└── git-msg-tags.md  # Git commit message tags documentation
scripts/             # CLI and utility scripts
└── pre-commit       # Git pre-commit hook script
src/                 # Source code files, which can also be `lib`
tests/               # Test cases
Makefile             # High-level entrance for this project
README.md            # In almost every folder, a README.md should explain its purpose
.gitignore           # Git ignore file
```

Refer to `./sdk.md` for more information about the SDK structure created by `lol init`.

### Makefile Interfaces

- `make test` - Run all test cases (bash by default)
- `make test-shells` - Run all test cases under multiple shells (bash and zsh)
- `make test-sdk` - Run SDK template tests
- `make test-cli` - Run CLI command tests
- `make test-lint` - Run validation and linting tests
- `make test-e2e` - Run end-to-end integration tests
- `make test-fast` - Run fast tests (sdk + cli + lint)
- `make setup` - Creates a `setup.sh` script to set up the development environment
  - NOTE: This does not run the setup itself as it only affects the subshell
  - To run the setup, use `source ./setup.sh`
  - Of course, `setup.sh` should be in `.gitignore`
  - This design decision is made because many projects rely on its repo path in `setup.sh`,
  while hardcoding it in `setup.sh` is a bad practice.
  - The `.claude/hooks/session-init.sh` hook uses `make setup` and sources `setup.sh` to
  export `AGENTIZE_HOME` for the active worktree (main or linked)
- `make pre-commit` - Installs the git pre-commit hook
- `make clean` - Cleans up generated files
- `make help` - Displays help information about available Makefile targets

## Git Usage

### Installation

**One-command install (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

The installer:
1. Clones the bare repository to `$HOME/.agentize` (or custom `--dir`)
2. Runs `wt init` to create `trees/main` worktree
3. Executes `make setup` in `trees/main` to generate `setup.sh`
4. Prints shell RC integration instructions

See [docs/cli/install.md](../cli/install.md) for options and troubleshooting.

**Manual setup:**

This development workflow uses bare repos for multiple worktrees:
- Clone your repo `git clone --bare <repo-url> <repo-name>.git`
- Initialize worktree environment `wt init` (run once, creates `trees/main`)
- Run `make setup` in `trees/main` to generate `setup.sh` with `AGENTIZE_HOME` set
- Source `setup.sh` to enable `wt` and `lol` commands

### Worktree Management

- Switch to main worktree: `wt goto main`
- Create worktree for issue: `wt spawn <issue-number>`
  - NOTE: `spawn` is an all-in-one command that creates the worktree, `cd`s into it, and launches Claude Code with the issue implementation prompt
  - Example: `wt spawn 42`

**Repository structure:**

```plaintext
<repo-name>.git/      # Bare git repository
├── trees/            # Worktrees directory
│     ├── main/       # Main worktree (run 'make setup' here)
│     ├── issue-42/   # Worktree for issue #42
│     └── ...         # Other worktrees
└── .../              # Other git internal files
```

## CLI Implementation

The Agentize CLI commands (`wt`, `lol`) follow a source-first architecture where:
- Canonical implementations live in `src/cli/` as sourceable libraries
- `setup.sh` sources these libraries to provide shell functions
- Wrapper scripts in `scripts/` delegate to the library functions

This pattern provides:
- Single source of truth for CLI logic
- Functions available in interactive shells via `setup.sh`
- Direct script execution for testing and non-interactive use

## GitHub Usage

It is preferred to associate each repository with a GitHub Projects v2 board for better issue tracking and project management.

**Create or associate a project:**
- `lol project --create [--org <org>] [--title <title>]` - Create a new GitHub Projects v2 board and associate it
- `lol project --associate <org>/<id>` - Associate the current repo to an existing GitHub Projects v2 board

**Generate automation template:**
- `lol project --automation [--write <path>]` - Generate a GitHub Actions workflow for project automation with lifecycle management (auto-add issues/PRs, set Stage "proposed" for issues, close linked issues on PR merge)

**Metadata storage:**
- The project association is stored in `.agentize.yaml` with `project.org` and `project.id` fields
- Refer to `./metadata.md` for more information about `.agentize.yaml` structure

**Related documentation:**
- Refer to `./project.md` for Kanban design and project management workflow
- Refer to `../workflows/github-projects-automation.md` for automation setup