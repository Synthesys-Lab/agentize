# wt.sh Interface Documentation

Implementation of the `wt` git worktree helper for bare repositories.

## External Interface

Functions exported for shell usage when sourced.

### wt()

Main command dispatcher and entry point.

**Usage:**
```bash
wt <command> [options]
```

**Parameters:**
- `$1`: Command name (common, init, goto, spawn, list, remove, prune, purge, help, --complete)
- `$@`: Remaining arguments passed to command implementation

**Return codes:**
- `0`: Command executed successfully
- `1`: Invalid command, command failed, or help displayed

**Commands:**
- `common`: Print git common directory (bare repo path)
- `init`: Initialize worktree environment
- `goto <target>`: Change directory to worktree (main or issue number)
- `spawn <issue-no>`: Create worktree for issue
- `list`: List all worktrees
- `remove <issue-no>`: Remove worktree for issue
- `prune`: Clean up stale worktree metadata
- `purge`: Remove worktrees for closed GitHub issues
- `help`: Display help message
- `--complete <topic>`: Shell completion helper

**Example:**
```bash
source src/cli/wt.sh
wt init
wt spawn 42
wt goto 42
```

### wt_common()

Get the git common directory (bare repository path) as absolute path.

**Parameters:** None

**Returns:**
- stdout: Absolute path to git common directory
- Return code: `0` on success, `1` if not in git repository

**Error conditions:**
- Not in a git repository

**Example:**
```bash
common_dir=$(wt_common)
echo "Bare repo at: $common_dir"
```

### wt_is_bare_repo()

Check if current repository is a bare repository.

**Parameters:** None

**Returns:**
- Return code: `0` if bare repository, `1` if not bare or not in git repo

**Detection logic:**
1. Check `git rev-parse --is-bare-repository` returns "true"
2. If in worktree, check if common directory has `core.bare = true`

**Example:**
```bash
if wt_is_bare_repo; then
    echo "This is a bare repository"
fi
```

### wt_get_default_branch()

Get the default branch name for the repository.

**Parameters:** None

**Returns:**
- stdout: Default branch name (main, master, or value from WT_DEFAULT_BRANCH)
- Return code: Always `0`

**Resolution order:**
1. `WT_DEFAULT_BRANCH` environment variable
2. HEAD symbolic reference in common directory
3. Verify `main` branch exists
4. Verify `master` branch exists
5. Default to "main" for new repos

**Example:**
```bash
default_branch=$(wt_get_default_branch)
echo "Default branch: $default_branch"
```

### wt_resolve_worktree()

Resolve worktree path by issue number or name.

**Parameters:**
- `$1`: Target (main | issue number)

**Returns:**
- stdout: Absolute path to worktree directory
- Return code: `0` if found, `1` if not found

**Resolution logic:**
- "main" → `<common-dir>/trees/main`
- Numeric (e.g., "42") → `<common-dir>/trees/issue-42*` (matches "issue-42" or "issue-42-title")

**Example:**
```bash
worktree_path=$(wt_resolve_worktree "42")
if [ $? -eq 0 ]; then
    cd "$worktree_path"
fi
```

## Command Implementations

Internal command handler functions called by main dispatcher.

### cmd_common()

Print the git common directory path.

**Parameters:** None

**Output:** Absolute path to git common directory

**Return codes:**
- `0`: Success
- `1`: Not in git repository

### cmd_init()

Initialize worktree environment by creating trees/main.

**Parameters:** None

**Prerequisites:**
- Must be in a bare git repository
- Default branch (main/master) must exist

**Operations:**
1. Verify bare repository
2. Determine default branch
3. Prune stale worktree metadata
4. Create `trees/main` worktree from default branch

**Return codes:**
- `0`: Initialization successful or already initialized
- `1`: Not in bare repo, trees/main creation failed

**Error conditions:**
- Not in bare repository → Error message with migration guide
- Default branch not found → Error message
- Worktree creation fails → Error message

**Environment variables:**
- `WT_DEFAULT_BRANCH`: Override default branch detection

### cmd_goto()

Change current directory to specified worktree.

**Parameters:**
- `$1`: Target (main | issue number)

**Prerequisites:**
- Must be sourced (not executed directly)
- Target worktree must exist

**Operations:**
1. Resolve worktree path using `wt_resolve_worktree()`
2. Change directory to worktree
3. Export `WT_CURRENT_WORKTREE` for subshells

**Return codes:**
- `0`: Directory changed successfully
- `1`: Missing target, worktree not found, cd failed

**Error conditions:**
- No target provided → Usage error
- Worktree not found → Error message with target

### cmd_spawn()

Create new worktree for issue from default branch.

**Parameters:**
- `$1-$n`: Issue number and optional flags

**Flags:**
- `--no-agent`: Skip automatic Claude invocation
- `--yolo`: Skip permission prompts (pass to Claude)
- `--headless`: Run Claude in non-interactive mode (uses `--print`, logs to `.tmp/logs/`)

**Prerequisites:**
- Trees directory must exist (wt init must be run)
- gh CLI available for issue validation
- Issue must exist on GitHub

**Operations:**
1. Parse arguments (issue number and flags)
2. Validate issue number (numeric)
3. Validate issue exists via `gh issue view`
4. Determine branch name (issue-N or issue-N-title from gh)
5. Create worktree from default branch
6. Add pre-trusted entry to `~/.claude.json` (requires `jq`)
7. Invoke Claude (unless --no-agent)

**Return codes:**
- `0`: Worktree created successfully
- `1`: Invalid arguments, issue not found, creation failed

**Error conditions:**
- Missing issue number → Usage error
- Non-numeric issue → Error message
- Issue not found → Error with gh CLI hint
- Worktree already exists → Error message
- Git worktree creation fails → Detailed error with branch/path/base info

**Environment variables:**
- `WT_DEFAULT_BRANCH`: Override default branch

### cmd_remove()

Remove worktree and optionally delete branch.

**Parameters:**
- `$1-$n`: Issue number and optional flags

**Flags:**
- `--delete-branch`: Delete branch even if unmerged
- `-D`: Alias for --delete-branch
- `--force`: Alias for --delete-branch

**Prerequisites:**
- Worktree must exist for given issue number

**Operations:**
1. Parse arguments (issue number and flags)
2. Resolve worktree path
3. Extract branch name from worktree metadata
4. Remove worktree
5. Delete branch if requested

**Return codes:**
- `0`: Worktree removed successfully
- `1`: Missing issue number, worktree not found, removal failed

**Error conditions:**
- No issue number → Usage error
- Worktree not found → Warning message

### cmd_list()

List all worktrees.

**Parameters:** None

**Output:** `git worktree list` output

**Return codes:**
- `0`: Always (delegates to git)

### cmd_prune()

Clean up stale worktree metadata.

**Parameters:** None

**Output:** `git worktree prune` output

**Return codes:**
- `0`: Always (delegates to git)

### cmd_purge()

Remove worktrees for closed GitHub issues.

**Parameters:** None

**Prerequisites:**
- gh CLI must be available

**Operations:**
1. Verify gh CLI available
2. Find all `trees/issue-*` worktrees
3. Extract issue number from directory name
4. Check issue state via `gh issue view --json state --jq '.state'`
5. If CLOSED: remove worktree and delete branch

**Return codes:**
- `0`: Purge completed (even if no closed issues)
- `1`: gh CLI not found, not in git repository

**Output:**
- Status messages for each removed worktree
- Summary of purged count

**Error conditions:**
- gh CLI not available → Error message
- Not in git repository → Error message

### cmd_help()

Display help message.

**Parameters:** None

**Output:** Help text to stdout

**Return codes:**
- `0`: Always

**Help content:**
- Command usage
- All available commands
- Options for spawn and remove
- Examples

## Internal Helpers

Helper functions not intended for external use.

### Completion Helper (--complete topic)

Provides completion data for shell completion systems.

**Topics:**
- `commands`: List all commands (newline-delimited)
- `spawn-flags`: List spawn flags (--yolo, --no-agent)
- `remove-flags`: List remove flags (--delete-branch, -D, --force)
- `goto-targets`: List available worktree targets (main + issue-*)

**Return codes:**
- `0`: Always

**Output format:** Newline-delimited tokens, no descriptions

## Usage Patterns

### Sourcing vs Execution

The file can be sourced or executed:

**Sourced:**
```bash
source src/cli/wt.sh
wt goto main  # Changes current shell directory
```

**Executed:**
```bash
./src/cli/wt.sh help  # Shows help, exits
```

**Detection:**
```bash
# File detects sourcing via:
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Executed directly
    wt "$@"
    exit $?
fi
# Sourced - wt() function available
```

### Error Handling

All commands follow consistent error handling:

1. Validate prerequisites (git repo, bare repo, etc.)
2. Validate arguments
3. Perform operation
4. Return appropriate exit code
5. Print clear error messages to stderr

### Environment Integration

**Required environment:** None (works standalone)

**Optional dependencies:**
- `jq`: Used by spawn to pre-trust worktree in `~/.claude.json`

**Optional environment:**
- `WT_DEFAULT_BRANCH`: Override branch detection
- `WT_CURRENT_WORKTREE`: Set by goto for subshell awareness

### Path Handling

All paths are converted to absolute:
- `wt_common()` ensures absolute path from git common dir
- Worktree paths are always absolute
- No relative path assumptions

## Testing

See `tests/cli/test-wt-*.sh` for comprehensive test coverage:
- `test-wt-bare-repo-required.sh`: Bare repo enforcement
- `test-wt-complete-*.sh`: Completion helper
- `test-wt-goto.sh`: Directory changing
- `test-wt-purge.sh`: Closed issue cleanup

All tests use `tests/helpers-worktree.sh` for test repository setup.
