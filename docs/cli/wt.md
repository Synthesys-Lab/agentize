# `wt`: Git worktree helper

## Getting Started

This is a part of `source setup.sh`.
After that, you can use the `wt` command in your terminal.
`wt` are just wrappers around `git worktree`.

> NOTE1: `wt` is implemented in `src/cli/wt.sh` while this source file is NOT executable alone.
> The correct usage is ALWAYS through `source setup.sh` which imports all the functions and commands inside.
>
> NOTE2: `wt` commands must be run inside a git bare git repo. DO NOT get confused, this is NOT a tool specific
> to `agentize` it is a general-purpose git worktree helper.

- `wt common`: `git rev-parse --git-common-dir`
- `wt init`
  - If `wt common` is not a bare repo, it dumps an error and exits.
  - This is **mandatory**: 1) run this once per repository, 2) the repository must be a bare git clone (no existing worktrees)
  - It creates `trees/` directory in that repo, and checks out the main/master worktree into `trees/main`
  - If it is already initialized, it should be idempotent, just dump "This repository is already initialized."
- `wt goto <issue-no>`: `cd trees/issue-<issue-no>-*`
  - `wt goto main`: `cd trees/main`
  - Both `main` and `issue-<issue-no>-` should be auto-completable
- `wt spawn <issue-no>`: create a new worktree for the given issue number from the `main` branch
  - Before creating the worktree, it `git pull --rebase` the latest `main` branch
  - `--no-agent`: skip automatic Claude invocation after worktree creation
  - `--yolo`: skip permission prompts by passing `--dangerously-skip-permissions` to Claude
- `wt remove <issue-no>`: remove the worktree for the given issue number
  - `--delete-branch`: delete the branch as well, even if unmerged
- `wt list`: list all existing worktrees
- `wt purge`
  - It iterates over each worktree starts with `issue-` and checks the corresponding `issue-` on `gh` CLI. If the issue is closed, remove both the worktree and the branch.
  - Each removal should also have the branch removed, and dump a "Branch and worktree of issue-<issue-no> removed." message on stdout.
- `wt help`: show help message

## Shell Completion (zsh)

The `wt` command provides tab-completion support for zsh users. After running `make setup` and sourcing `setup.sh`, completions are automatically enabled.

**Features:**
- Subcommand completion (`wt <TAB>` shows: init, main, spawn, list, remove, prune, help)
- Flag completion for `spawn` (`--yolo`, `--no-agent`) — flags can appear before or after `<issue-no>`
- Flag completion for `remove` (`-D`, `--force`) — flags can appear before or after `<issue-no>`

**Setup:**
1. Run `make setup` to generate `setup.sh`
2. Source `setup.sh` in your shell: `source setup.sh`
3. Tab-completion will be available for `wt` commands

**Implementation:** The zsh completion system uses the `wt --complete` helper (see Completion Helper Interface) to dynamically fetch available flags and commands.

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
remove
prune
help

$ wt --complete spawn-flags
--yolo
--no-agent
```

This helper is used by the zsh completion system and can be used by other shells in the future.
