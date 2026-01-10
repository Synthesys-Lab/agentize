# `wt`: Git worktree helper

## Getting Started

After running `make setup` and sourcing `setup.sh`, the `wt` command is available in your terminal. `wt` is a wrapper around `git worktree` for managing multiple worktrees in a bare repository.

**Installation context:**
- The installer script (`scripts/install`) sets up the bare repository structure automatically
- Manual setup: Clone as bare repo, run `wt init`, then `make setup` in `trees/main`

**Repository context:**
- `wt` commands operate on bare git repositories (not regular clones)
- Worktrees are created under `trees/` directory in the bare repo root
- The installer creates this structure: `<repo>.git/trees/main` where `make setup` generates `setup.sh`

> NOTE: `wt` is implemented in `scripts/wt-cli.sh` which is both executable and sourceable. The `wt` function wrapper is exported via `setup.sh`.

- `wt clone <url> [destination]`: clone a repository as bare, initialize worktrees, and set up `trees/main`
  - Equivalent to: `git clone --bare <url> <dest>` followed by `wt init` and `wt goto main`
  - If `destination` omitted, defaults to `<basename>.git` (e.g., `repo` from `https://github.com/org/repo.git`)
  - When sourced, leaves the user in `trees/main` (same as `wt goto` behavior)
  - Fails if destination directory already exists
- `wt common`: prints the bare repository path (`git rev-parse --git-common-dir`)
- `wt init`
  - If `wt common` is not a bare repo, it dumps an error and exits.
  - This is **mandatory**: 1) run this once per repository, 2) the repository must be a bare git clone (no existing worktrees)
  - It creates `trees/` directory in that repo, and checks out the main/master worktree into `trees/main`
  - If it is already initialized, it should be idempotent, just dump "This repository is already initialized."
  - Uses `WT_DEFAULT_BRANCH` environment variable if set, otherwise defaults to `main` or `master`
- `wt goto <issue-no>|main`: changes directory to the worktree target
  - `wt goto main`: changes to `trees/main`
  - `wt goto <issue-no>`: changes to `trees/issue-<issue-no>` (wildcard pattern `issue-<issue-no>*` used for compatibility)
  - Both `main` and `issue-<issue-no>` should be auto-completable
- `wt spawn <issue-no>`: create a new worktree for the given issue number from the `main` branch
  - Before creating the worktree, it rebases onto the latest default branch from the bare repo
  - After creating the worktree, attempts to update the issue's GitHub Projects v2 Status to "In Progress" (best-effort)
  - `--no-agent`: skip automatic Claude invocation after worktree creation
  - `--yolo`: skip permission prompts by passing `--dangerously-skip-permissions` to Claude
    - **WARNING**: When active, Claude will run with all permission checks bypassed
    - A warning message will be displayed on stderr before Claude invocation
  - `--headless`: run Claude in non-interactive mode for server daemon use
    - Uses `claude --print` for non-interactive execution
    - Logs output to `.tmp/logs/issue-<N>-<timestamp>.log`
    - Returns immediately (non-blocking) with structured output:
      ```
      PID: <claude-pid>
      Log: <log-file-path>
      ```
    - The PID corresponds to the actual `claude` process for liveness tracking
- `wt remove <issue-no>`: remove the worktree for the given issue number
  - `--delete-branch`: delete the branch as well, even if unmerged
  - `-D` / `--force`: legacy aliases for `--delete-branch`
- `wt list`: list all existing worktrees
- `wt prune`: clean up stale worktree metadata (`git worktree prune`)
- `wt purge`
  - It iterates over each worktree starting with `issue-` and checks the corresponding issue on `gh` CLI. If the issue is closed, remove both the worktree and the branch.
  - Each removal should also have the branch removed, and dump a "Branch and worktree of issue-<issue-no> removed." message on stdout.
- `wt pathto <target>`: print the absolute path to a worktree
  - `wt pathto main`: prints path to `trees/main`
  - `wt pathto <issue-no>`: prints path to `trees/issue-<issue-no>*`
  - Exits `0` on success, `1` if worktree not found
  - Useful for scripting and programmatic worktree lookups
- `wt rebase <pr-no>`: rebase the worktree for the given PR onto the default branch using a Claude Code session
  - Resolves issue/worktree from PR metadata using fallbacks:
    1. Branch name pattern `issue-<N>`
    2. `closingIssuesReferences` from PR
    3. `#<N>` token in PR body
  - Invokes Claude Code with `/sync-master` skill to perform the rebase
  - `--headless`: run Claude in non-interactive mode for server daemon use
    - Uses `claude --print` for non-interactive execution
    - Logs output to `.tmp/logs/rebase-<pr-no>-<timestamp>.log`
    - Returns immediately (non-blocking) with structured output:
      ```
      PID: <claude-pid>
      Log: <log-file-path>
      ```
  - `--yolo`: skip permission prompts by passing `--dangerously-skip-permissions` to Claude
- `wt help`: show help message

## Bare Repository Requirement

`wt` is designed for **bare git repositories** only. A bare repository is a git repository without a working directory, typically created with `git clone --bare`.

**Why bare repositories?**
- Cleanly separates the repository storage from working directories
- Allows multiple worktrees without conflicts
- Prevents accidental commits to the repository directory itself

**Migration guide:**
If you have an existing non-bare repository, convert it to a bare repository:

```bash
# 1. Clone your existing repo as bare
git clone --bare /path/to/existing/repo /path/to/bare/repo

# 2. Initialize worktree environment
cd /path/to/bare/repo
wt init

# 3. Your main branch is now at trees/main
cd trees/main
```

## Shell Completion (zsh)

The `wt` command provides tab-completion support for zsh users. After running `make setup` and sourcing `setup.sh`, completions are automatically enabled.

**Features:**
- Subcommand completion (`wt <TAB>` shows: clone, common, init, goto, spawn, list, remove, prune, purge, pathto, rebase, help)
- Flag completion for `spawn` (`--yolo`, `--no-agent`, `--headless`) — flags can appear before or after `<issue-no>`
- Flag completion for `remove` (`--delete-branch`, `-D`, `--force`) — flags can appear before or after `<issue-no>`
- Flag completion for `rebase` (`--headless`) — flags can appear before or after `<pr-no>`
- Target completion for `goto` (`main` and `issue-<N>-*` worktrees)
- Target completion for `pathto` (same targets as `goto`)

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
- `commands` - List available subcommands (clone, common, init, goto, spawn, list, remove, prune, purge, pathto, rebase, help)
- `spawn-flags` - List flags for `wt spawn` (--yolo, --no-agent, --headless)
- `remove-flags` - List flags for `wt remove` (--delete-branch, -D, --force)
- `rebase-flags` - List flags for `wt rebase` (--headless, --yolo)
- `goto-targets` - List available targets for `wt goto` (main and issue-<N>-* worktrees)

**Output format:** Newline-delimited tokens, no descriptions.

**Example:**
```bash
$ wt --complete commands
clone
common
init
goto
spawn
list
remove
prune
purge
pathto
rebase
help

$ wt --complete spawn-flags
--yolo
--no-agent
--headless

$ wt --complete goto-targets
main
issue-42
issue-45

$ wt --complete rebase-flags
--headless
--yolo
```

This helper is used by the zsh completion system and can be used by other shells in the future.
