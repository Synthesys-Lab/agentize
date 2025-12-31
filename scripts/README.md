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
  - Validates folder README.md existence
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
    - `create <issue-number> [description]` - Create worktree with GitHub title fetch
    - `list` - Show all active worktrees
    - `remove <issue-number>` - Remove worktree by issue number
    - `prune` - Clean up stale worktree metadata
  - Features:
    - Automatically fetches issue titles from GitHub via `gh` CLI
    - Creates branches following `issue-<N>-<title>` convention
    - Limits suffix length to 10 characters (configurable via `WORKTREE_SUFFIX_MAX_LENGTH`)
    - Bootstraps `CLAUDE.md` into each worktree
    - Worktrees stored in `trees/` directory (gitignored)
  - Exit codes: 0 (success), 1 (error)
  - Examples:
    ```bash
    # Create worktree fetching title from GitHub issue #42
    ./scripts/wt-cli.sh create 42

    # Create worktree with custom description
    ./scripts/wt-cli.sh create 42 add-feature

    # List all worktrees
    ./scripts/wt-cli.sh list

    # Remove worktree (force removes with uncommitted changes)
    ./scripts/wt-cli.sh remove 42
    ```

- `worktree.sh` - Legacy worktree management (use `wt-cli.sh` instead)

### Makefile Utilities

#### Agentize Mode Scripts
- `agentize-init.sh` - Initialize new project with agentize templates
  - Usage: Called by `lol init` command
  - Environment variables: `AGENTIZE_PROJECT_PATH`, `AGENTIZE_PROJECT_NAME`, `AGENTIZE_PROJECT_LANG`
  - Creates language template structure, copies `.claude/` content, applies substitutions
  - Executes `bootstrap.sh` if present in project directory
  - Exit codes: 0 (success), 1 (failure)

- `agentize-update.sh` - Update existing project with latest agentize configs
  - Usage: Called by `lol update` command
  - Environment variables: `AGENTIZE_PROJECT_PATH`
  - Backs up existing `.claude/` directory, refreshes configurations with file-level synchronization
  - File-level copy preserves user-added files (e.g., custom skills, commands, agents) while updating template files
  - Ensures `docs/git-msg-tags.md` exists using language detection
  - Exit codes: 0 (success), 1 (failure)

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

#### Language Detection
- `detect-lang.sh` - Automatic language detection for projects
  - Usage: `./scripts/detect-lang.sh <project_path>`
  - Detects project language based on file structure
  - Detection rules:
    - **Python**: Looks for requirements.txt, pyproject.toml, or *.py files
    - **C**: Looks for CMakeLists.txt without CXX language
    - **C++**: Looks for CMakeLists.txt with CXX language
  - Outputs detected language to stdout: "python", "c", or "cxx"
  - Writes warnings to stderr if unable to detect
  - Exit codes: 0 (detected), 1 (unable to detect)
  - Example:
    ```bash
    LANG=$(./scripts/detect-lang.sh "/path/to/project")
    if [ $? -eq 0 ]; then
        echo "Detected language: $LANG"
    fi
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
