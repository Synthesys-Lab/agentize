# lol.sh Interface Documentation

Implementation of the `lol` SDK CLI for AI-powered project management.

## Module Structure

The implementation is split into sourced modules in `lol/`:

| Module | Purpose |
|--------|---------|
| `helpers.sh` | Language detection and utility functions |
| `completion.sh` | Shell-agnostic completion helper (`_lol_complete`) |
| `commands.sh` | Thin loader that sources `commands/*.sh` |
| `commands/` | Per-command implementations (`_lol_cmd_*`) |
| `dispatch.sh` | Main dispatcher, help text, and `lol` function |
| `parsers.sh` | Argument parsing for each command |

`lol.sh` sources these modules in order. The public entrypoint remains `lol()`, while helpers and command functions are private.

The `commands/` directory contains individual files for each command:
- `upgrade.sh`, `version.sh`
- `project.sh`, `serve.sh`, `claude-clean.sh`, `usage.sh`, `plan.sh`

## External Interface

Functions exported for shell usage when sourced. `lol()` is the only public entrypoint.

### lol()

Main command dispatcher and entry point.

**Usage:**
```bash
lol <command> [options]
```

**Parameters:**
- `$1`: Command name (upgrade, project, plan, usage, claude-clean, --version, --complete)
- `$@`: Remaining arguments passed to command implementation

**Return codes:**
- `0`: Command executed successfully
- `1`: Invalid command, command failed, or help displayed

**Logging Behavior:**
- At startup, logs version information to stderr: `[agentize] <version-tag-or-commit> @ <full-commit-hash>`
- Version information comes from git tags (via `git describe --tags --always` from `AGENTIZE_HOME`) and commit hash (via `git rev-parse HEAD`)
- Logging is suppressed for `--complete` mode to avoid polluting completion output

**Commands:**
- `upgrade`: Upgrade agentize installation
- `project`: GitHub Projects v2 integration
- `plan`: Run the multi-agent debate pipeline
- `usage`: Report Claude Code token usage
- `claude-clean`: Remove stale project entries from `~/.claude.json`
- `--version`: Display version information
- `--complete <topic>`: Shell completion helper

**Example:**
```bash
source src/cli/lol.sh
lol upgrade
lol project --create
```

## Internal Helpers

Private helpers and command implementations used by `lol()` and wrappers. These are not part of the public shell API.

### _lol_complete()

Shell-agnostic completion helper for completion systems.

**Parameters:**
- `$1`: Topic name

**Returns:**
- stdout: Newline-delimited tokens for completion
- Return code: Always `0`

**Topics:**
- `commands`: List available subcommands
- `project-modes`: List project mode flags
- `project-create-flags`: List flags for `lol project --create`
- `project-automation-flags`: List flags for `lol project --automation`
- `claude-clean-flags`: List flags for `lol claude-clean`
- `usage-flags`: List flags for `lol usage`
- `plan-flags`: List flags for `lol plan` (`--dry-run`, `--verbose`, `--editor`)

**Example:**
```bash
_lol_complete commands
# Output:
# upgrade
# project
# usage
# claude-clean
```

### _lol_detect_lang()

Detect project language based on file structure.

**Parameters:**
- `$1`: Project path

**Returns:**
- stdout: Detected language (python, c, cxx)
- Return code: `0` if detected, `1` if unable to detect

**Detection logic:**
1. Python: `requirements.txt`, `pyproject.toml`, or `*.py` files
2. C++: `CMakeLists.txt` with `project.*CXX`
3. C: `CMakeLists.txt` without CXX

**Example:**
```bash
lang=$(_lol_detect_lang "/path/to/project")
if [ $? -eq 0 ]; then
    echo "Detected: $lang"
fi
```

### Command Implementations (private)

Subshell command functions called by main dispatcher. Each runs in a subshell to preserve `set -e` semantics and isolate environment variables.

#### _lol_cmd_upgrade()

Upgrade agentize installation via git pull and rebuild environment.

**Parameters:** None (rejects any arguments)

**Operations:**
1. Validate `AGENTIZE_HOME` is a git worktree
2. Check for uncommitted changes (dirty-tree guard)
3. Resolve default branch from `origin/HEAD`
4. Run `git pull --rebase origin <branch>`
5. Run `make setup` to rebuild environment configuration
6. Print shell reload instructions on success

**Return codes:**
- `0`: Upgrade successful
- `1`: Not a worktree, dirty tree, rebase failed, or make setup failed

#### _lol_cmd_project()

GitHub Projects v2 integration.

**Signature:**
```bash
_lol_cmd_project <mode> [arg1] [arg2] [arg3]
```

**Parameters:**
- `mode`: Operation mode - create, associate, automation (required)
- For `create` mode:
  - `arg1`: Organization (optional, defaults to repo owner)
  - `arg2`: Project title (optional, defaults to repo name)
- For `associate` mode:
  - `arg1`: org/id argument (required, e.g., "Synthesys-Lab/3")
- For `automation` mode:
  - `arg1`: Write path for workflow file (optional, outputs to stdout if not specified)

**Modes:**

**create:**
- Creates new GitHub Projects v2 board
- Updates `.agentize.yaml` with project metadata
- Requires `gh` CLI authentication

**associate:**
- Associates existing project board
- Validates project exists via GraphQL
- Updates `.agentize.yaml` with project metadata

**automation:**
- Generates GitHub Actions workflow template
- Auto-configures Stage field if project is accessible
- Outputs to stdout or writes to specified path

**Return codes:**
- `0`: Operation successful
- `1`: Invalid mode, project not found, or API error

#### _lol_cmd_plan()

Run the multi-agent debate pipeline via `lol plan`.

**Signature:**
```bash
_lol_cmd_plan <feature_desc_or_refine_instructions> <issue_mode> <verbose> \
  <refine_issue_number>
```

**Parameters:**
- `feature_desc_or_refine_instructions`: Feature description string, or refinement instructions when refining (required unless `refine_issue_number` is set)
- `issue_mode`: `"true"` to create/update GitHub issue, `"false"` to skip publish (required)
- `verbose`: `"true"` for detailed logs, `"false"` for quiet mode (required)
- `refine_issue_number`: Issue number to refine (optional)

**Operations:**
1. Lazily load planner modules (sources `planner.sh` if not already loaded)
2. Call `_planner_run_pipeline` with parsed flags, including optional refine issue number

**Return codes:**
- `0`: Pipeline completed successfully
- `1`: Missing or invalid arguments
- `2`: Stage execution failure

#### _lol_cmd_claude_clean()

Remove stale project entries from `~/.claude.json`.

**Signature:**
```bash
_lol_cmd_claude_clean <dry_run>
```

**Parameters:**
- `dry_run`: "1" for preview mode, "0" for apply mode (required)

**Operations:**
1. Resolve config path (`$HOME/.claude.json`)
2. Verify `jq` is available
3. Extract paths from `.projects` keys and `.githubRepoPaths` arrays
4. Check each path for existence via `test -d`
5. If `dry_run=1`, print summary and exit
6. Otherwise, apply jq filter to remove stale entries
7. Write atomically via temp file and `mv`

**Return codes:**
- `0`: Operation successful (or no stale entries found)
- `1`: Missing dependency (jq) or write failed

#### _lol_cmd_version()

Display version information.

**Parameters:** None (rejects any arguments)

**Operations:**
1. Get installation commit from `AGENTIZE_HOME`
2. Get project commit from `.agentize.yaml` (if present)
3. Display formatted version information

**Output format:**
```
Installation: <commit-hash>
Last update:  <commit-hash>
```

**Return codes:**
- `0`: Always
- `1`: Unexpected arguments provided

#### _lol_cmd_usage()

Report Claude Code token usage statistics via the Python usage module. See
`lol/commands/usage.md` for flag handling and output formatting.

#### _lol_cmd_serve()

Start the polling server for automation workflows. Configuration is loaded from
`.agentize.local.yaml` (no CLI flags). See `lol/commands/serve.md` for details.

#### _lol_cmd_impl()

Drive the issue-to-implementation loop (`lol impl`) and manage per-iteration
commit reports. See `lol/commands/impl.md` for the workflow contract.

## Internal Helpers

### YAML Parsing

Simple YAML parsing for `.agentize.yaml`:
- `read_metadata <key>`: Extract value from project section
- `update_metadata <key> <value>`: Update or add field

### Path Resolution

- All paths converted to absolute before use
- Project root detection via `git rev-parse --show-toplevel`

## Usage Patterns

### Sourcing vs Execution

**Sourced (primary usage):**
```bash
source setup.sh  # Sources src/cli/lol.sh
lol upgrade
```

**Executed (testing):**
```bash
./src/cli/lol.sh help
```

### Error Handling

All commands follow consistent error handling:
1. Validate `AGENTIZE_HOME` is set and valid
2. Validate command-specific requirements
3. Perform operation in subshell
4. Return appropriate exit code
5. Print clear error messages to stderr

### Environment Integration

**Required environment:**
- `AGENTIZE_HOME`: Path to agentize installation

**Optional environment:**
- None (all other values derived or defaulted)

## Testing

See `tests/cli/test-lol-*.sh` and `tests/e2e/test-lol-*.sh` for test coverage.
