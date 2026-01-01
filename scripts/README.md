# Scripts Directory

This directory contains utility scripts and git hooks for the project.

## Files

### Pre-commit Hook
- `pre-commit` - Git pre-commit hook script
  - Runs documentation linter before tests
  - Executes all test suites via `tests/test-all.sh`
  - Can be bypassed with `--no-verify` for milestone commits

### Documentation Linter
- `lint-documentation.sh` - Pre-commit documentation linter
  - Validates folder documentation (README.md, or SKILL.md for skill directories)
  - Validates source code .md file correspondence
  - Validates test documentation presence
  - Exit codes: 0 (pass), 1 (fail)

- `lint-documentation.md` - Documentation for the linter itself
  - External interface (usage, exit codes)
  - Internal helpers (check functions)
  - Examples of usage and output

### Git Worktree Helper
- `wt-cli.sh` - Worktree CLI and library (executable + sourceable)
  - Usage: `./scripts/wt-cli.sh <command> [args]`
  - Commands:
    - `init` - Initialize worktree environment (creates trees/main)
    - `main` - Switch to main worktree (when sourced)
    - `spawn <issue-number> [description]` - Create worktree with GitHub title fetch
    - `list` - Show all active worktrees
    - `remove <issue-number>` - Remove worktree by issue number
    - `prune` - Clean up stale worktree metadata
    - `help` - Display help information
  - Features:
    - Automatically fetches issue titles from GitHub via `gh` CLI
    - Creates branches following `issue-<N>-<title>` convention
    - Limits suffix length to 10 characters (configurable via `WORKTREE_SUFFIX_MAX_LENGTH`)
    - Bootstraps `CLAUDE.md` into each worktree
    - Worktrees stored in `trees/` directory (gitignored)
  - Exit codes: 0 (success), 1 (error)
  - Examples:
    ```bash
    # Initialize worktree environment
    ./scripts/wt-cli.sh init

    # Create worktree fetching title from GitHub issue #42
    ./scripts/wt-cli.sh spawn 42

    # Create worktree with custom description
    ./scripts/wt-cli.sh spawn 42 add-feature

    # List all worktrees
    ./scripts/wt-cli.sh list

    # Remove worktree (force removes with uncommitted changes)
    ./scripts/wt-cli.sh remove 42
    ```

- `worktree.sh` - Legacy worktree management (use `wt-cli.sh` instead)

### CLI Utilities

#### lol CLI
- `lol-cli.sh` - Project SDK initialization and update entrypoint
  - Usage: `lol init --name <name> --lang <lang> [--path <path>] [--metadata-only]`
  - Usage: `lol update [--path <path>]`
  - Handles:
    - `init`: Creates project structure with templates and `.agentize.yaml`
    - `update`: Syncs `.claude/` configuration and ensures metadata exists (metadata-first language resolution with internal detection fallback)
  - Internal functions: initialization, update workflows, metadata handling, pre-commit hook installation
  - Exit codes: 0 (success), 1 (failure)

#### YAML Parsing Utility
- `yaml-parser.sh` - Shared YAML value extraction utility
  - Usage: `source scripts/yaml-parser.sh; parse_yaml_value <file> <section.field>`
  - Provides: `parse_yaml_value` function for nested YAML field parsing
  - Used by: `lol-cli.sh`, `wt-cli.sh`
  - Exit codes: 0 (value found), 1 (not found or file missing)

#### Parameter Validation
- `check-parameter.sh` - Mode-based parameter validation for agentize target
  - Usage: `./scripts/check-parameter.sh <mode> <project_path> <project_name> <project_lang>`
  - Validates required parameters based on mode (init/update)
  - For **init mode**: Validates PROJECT_PATH, PROJECT_NAME, PROJECT_LANG, and template existence
  - For **update mode**: Only validates PROJECT_PATH
  - Exit codes: 0 (success), 1 (validation failed)
  - Example:
    ```bash
    ./scripts/check-parameter.sh "init" "/path/to/project" "my_project" "python"
    ```

## Usage

### Installing Pre-commit Hook

The pre-commit hook should be linked to `.git/hooks/pre-commit`:

```bash
# Link to git hooks (typically done during project setup)
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

### Cross-Project Function Setup

For the agentize repository itself, use `make setup` to generate a `setup.sh` with hardcoded paths:

```bash
make setup
source setup.sh
# Add 'source /path/to/agentize/setup.sh' to your shell RC for persistence
```

This enables `wt` and `lol` CLI commands from any directory.

### Running Linter Manually

```bash
# Run on all tracked files
./scripts/lint-documentation.sh

# Check specific files (via git staging)
git add path/to/files
git commit  # Linter runs automatically
```

### Bypassing Hooks

For milestone commits where documentation exists but implementation is incomplete:

```bash
git commit --no-verify -m "[milestone] message"
```
