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
