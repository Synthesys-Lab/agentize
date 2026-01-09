# Scripts Directory

This directory contains utility scripts, git hooks, and wrapper entrypoints for the project.

**Canonical CLI sources:** The primary CLI implementations live in `src/cli/`. Scripts in this directory are either standalone utilities or thin wrappers that delegate to `src/cli/` libraries.

## Files

### Installer
- `install` - One-command Agentize installer script
  - Usage: `curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash`
  - Options:
    - `--dir <path>` - Installation directory (default: `$HOME/.agentize`)
    - `--repo <url-or-path>` - Git repository URL or local path (default: official GitHub repo)
    - `--help` - Display help and exit
  - Behavior:
    - Validates dependencies (`git`, `make`, `bash`)
    - Clones repository to install directory (or copies from local path)
    - Runs `wt init` to create `trees/main` worktree
    - Executes `make setup` in `trees/main` to generate `setup.sh`
    - Prints shell RC integration instructions
  - Safety features:
    - No automatic RC file modification
    - Fails if install directory exists (prevents overwrites)
  - Exit codes: 0 (success), 1 (error)
  - See [docs/cli/install.md](../docs/cli/install.md) for detailed documentation

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
- `wt-cli.sh` - Worktree CLI wrapper (sources `src/cli/wt.sh`)
  - Usage: `./scripts/wt-cli.sh <command> [args]`
  - Canonical source: `src/cli/wt.sh`
  - Commands:
    - `init` - Initialize worktree environment (creates trees/main)
    - `main` - Switch to main worktree (when sourced)
    - `spawn <issue-number>` - Create worktree with GitHub validation
    - `list` - Show all active worktrees
    - `remove <issue-number>` - Remove worktree by issue number
    - `prune` - Clean up stale worktree metadata
    - `help` - Display help information
  - Exit codes: 0 (success), 1 (error)

- `worktree.sh` - Legacy worktree management (use `wt-cli.sh` instead)

### SDK CLI Wrappers

These scripts delegate to `src/cli/lol.sh`:

- `agentize-project.sh` - Project command wrapper (calls `lol_cmd_project`)
  - Usage: Called by `lol project` command or directly with environment variables
  - Environment variables: `AGENTIZE_PROJECT_MODE`, `AGENTIZE_PROJECT_ORG`, etc.
  - Exit codes: 0 (success), 1 (failure)

- `detect-lang.sh` - Language detection wrapper (calls `lol_detect_lang`)
  - Usage: `./scripts/detect-lang.sh <project_path>`
  - Exit codes: 0 (detected), 1 (unable to detect)

### Makefile Utilities

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
