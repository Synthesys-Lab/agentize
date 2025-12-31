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

- `wt spawn <issue-no>`: Create a new worktree for the given issue number from the default branch.
  - Uses `git.default_branch` from `.agentize.yaml` if available
  - Falls back to detecting `main` or `master` branch
  - Creates worktree in `{trees_dir}/issue-{N}-{title}` format
- `wt remove <issue-no>`: Removes the worktree for the given issue number and deletes the corresponding branch.
- `wt list`: List all existing worktrees.
- `wt prune`: Remove stale worktree metadata.
