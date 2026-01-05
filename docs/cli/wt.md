# `wt`: Git worktree helper

## Getting Started

This is a part of `source setup.sh`.
After that, you can use the `wt` command in your terminal.

## Project Metadata Integration

`wt` reads project configuration from `.agentize.yaml` when available:

- **`git.default_branch`**: Specifies the default branch to use for creating new worktrees (e.g., `main`, `master`, `trunk`)
- **`worktree.trees_dir`** (optional): Specifies the directory for worktrees (defaults to `trees`)

When `.agentize.yaml` is missing, `wt` falls back to automatic detection (main/master) and displays a hint to run `lol init`.

## Commands and Subcommands

- `wt init`: Initialize the worktree environment by creating the main/master worktree.
  - Detects default branch (main or master)
  - Creates `trees/main` worktree from the detected branch
  - Moves repository root off main/master to enable worktree-based development
  - Installs pre-commit hook if available (unless `pre_commit.enabled: false` or hooks disabled via `core.hooksPath`)
  - Must be run before `wt spawn`
- `wt main`: Switch current directory to the main worktree.
  - Changes directory to `trees/main`
  - Only works when sourced (via `source setup.sh`)
  - Direct script execution shows an informational message
- `wt spawn [--yolo] [--no-agent] <issue-no>`: Create a new worktree for the given issue number from the default branch.
  - Uses `git.default_branch` from `.agentize.yaml` if available
  - Falls back to detecting `main` or `master` branch
  - Creates worktree in `{trees_dir}/issue-{N}` format
  - Validates issue existence using `gh issue view` (requires GitHub CLI)
  - Installs pre-commit hook in the new worktree if available (unless `pre_commit.enabled: false` or hooks disabled via `core.hooksPath`)
  - Requires `wt init` to be run first (trees/main must exist)
  - `--yolo`: Skip permission prompts by passing `--dangerously-skip-permissions` to Claude (use only in isolated containers/VMs)
  - `--no-agent`: Skip automatic Claude invocation after worktree creation
  - Note: Flags can appear before or after `<issue-no>` (e.g., `wt spawn 42 --yolo` or `wt spawn --yolo 42`)
- `wt remove [-D|--force] <issue-no>`: Removes the worktree for the given issue number and deletes the corresponding branch.
  - Uses safe deletion by default (`git branch -d`), which prevents deletion of unmerged branches
  - Use `-D` or `--force` to force-delete unmerged branches (`git branch -D`)
- `wt list`: List all existing worktrees.
- `wt prune`: Remove stale worktree metadata.
- `wt help`: Display help information about available commands.

## Shell Completion (zsh)

The `wt` command provides tab-completion support for zsh users. After running `make setup` and sourcing `setup.sh`, completions are automatically enabled.

**Features:**
- Subcommand completion (`wt <TAB>` shows: init, main, spawn, list, remove, prune, help)
- Flag completion for `spawn` (`--yolo`, `--no-agent`)
- Flag completion for `remove` (`-D`, `--force`)

**Setup:**
1. Run `make setup` to generate `setup.sh`
2. Source `setup.sh` in your shell: `source setup.sh`
3. Tab-completion will be available for `wt` commands

**Note:** Completion setup only affects zsh users. Bash users can continue using `wt` without any changes.

## Completion Helper Interface

The `wt` command includes a shell-agnostic completion helper for use by completion systems:

```bash
wt --complete <topic>
```

**Topics:**
- `commands` - List available subcommands (init, main, spawn, list, remove, prune, help)
- `spawn-flags` - List flags for `wt spawn` (--yolo, --no-agent)
- `remove-flags` - List flags for `wt remove` (-D, --force)

**Output format:** Newline-delimited tokens, no descriptions.

**Example:**
```bash
$ wt --complete commands
init
main
spawn
list
remove
prune
help

$ wt --complete spawn-flags
--yolo
--no-agent
```

This helper is used by the zsh completion system and can be used by other shells in the future.
