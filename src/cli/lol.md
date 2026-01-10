# lol.sh Interface Documentation

Implementation of the `lol` SDK CLI for AI-powered project management.

## Module Structure

The implementation is split into sourced modules in `lol/`:

| Module | Purpose |
|--------|---------|
| `helpers.sh` | Language detection and utility functions |
| `completion.sh` | Shell-agnostic completion helper (`lol_complete`) |
| `commands.sh` | Thin loader that sources `commands/*.sh` |
| `commands/` | Per-command implementations (`lol_cmd_*`) |
| `dispatch.sh` | Main dispatcher, help text, and `lol` function |
| `parsers.sh` | Argument parsing for each command |

`lol.sh` sources these modules in order. External interfaces remain unchanged.

The `commands/` directory contains individual files for each command:
- `init.sh`, `update.sh`, `upgrade.sh`, `version.sh`
- `project.sh`, `serve.sh`, `claude-clean.sh`

## External Interface

Functions exported for shell usage when sourced.

### lol()

Main command dispatcher and entry point.

**Usage:**
```bash
lol <command> [options]
```

**Parameters:**
- `$1`: Command name (init, update, upgrade, project, --version, --complete)
- `$@`: Remaining arguments passed to command implementation

**Return codes:**
- `0`: Command executed successfully
- `1`: Invalid command, command failed, or help displayed

**Commands:**
- `init`: Initialize new SDK project
- `update`: Update existing project configuration
- `upgrade`: Upgrade agentize installation
- `project`: GitHub Projects v2 integration
- `claude-clean`: Remove stale project entries from `~/.claude.json`
- `--version`: Display version information
- `--complete <topic>`: Shell completion helper

**Example:**
```bash
source src/cli/lol.sh
lol init --name my-project --lang python
lol update
```

### lol_complete()

Shell-agnostic completion helper for completion systems.

**Parameters:**
- `$1`: Topic name

**Returns:**
- stdout: Newline-delimited tokens for completion
- Return code: Always `0`

**Topics:**
- `commands`: List available subcommands
- `init-flags`: List flags for `lol init`
- `update-flags`: List flags for `lol update`
- `project-modes`: List project mode flags
- `project-create-flags`: List flags for `lol project --create`
- `project-automation-flags`: List flags for `lol project --automation`
- `claude-clean-flags`: List flags for `lol claude-clean`
- `lang-values`: List supported language values

**Example:**
```bash
lol_complete commands
# Output:
# init
# update
# upgrade
# project
```

### lol_detect_lang()

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
lang=$(lol_detect_lang "/path/to/project")
if [ $? -eq 0 ]; then
    echo "Detected: $lang"
fi
```

## Command Implementations

Subshell command functions called by main dispatcher. Each runs in a subshell to preserve `set -e` semantics and isolate environment variables.

### lol_cmd_init()

Initialize new SDK project with templates.

**Signature:**
```bash
lol_cmd_init <project_path> <project_name> <project_lang> [source_path] [metadata_only]
```

**Parameters:**
- `project_path`: Target project directory path (required)
- `project_name`: Project name for template substitutions (required)
- `project_lang`: Project language - python, c, cxx (required)
- `source_path`: Source code path relative to project root (optional, defaults to "src")
- `metadata_only`: If "1", create only metadata file (optional, defaults to "0")

**Operations:**
1. Validate required parameters
2. Create project directory if needed
3. Copy language templates (unless metadata-only)
4. Copy `.claude/` configuration (unless metadata-only)
5. Create `.agentize.yaml` with project metadata
6. Run `bootstrap.sh` if present (unless metadata-only)
7. Install pre-commit hook if conditions met

**Return codes:**
- `0`: Initialization successful
- `1`: Validation failed, directory not empty, or copy failed

### lol_cmd_update()

Update existing project with latest agentize configuration.

**Signature:**
```bash
lol_cmd_update <project_path>
```

**Parameters:**
- `project_path`: Target project directory path (required)

**Operations:**
1. Validate project path exists
2. Create `.claude/` directory if missing
3. Backup existing `.claude/` directory
4. Sync `.claude/` contents with file-level copy
5. Create `docs/git-msg-tags.md` if missing
6. Create `.agentize.yaml` if missing (best-effort metadata)
7. Record `agentize.commit` in metadata
8. Install pre-commit hook if conditions met
9. Print context-aware next steps

**Return codes:**
- `0`: Update successful
- `1`: Project path not found or update failed

### lol_cmd_upgrade()

Upgrade agentize installation via git pull.

**Parameters:** None (rejects any arguments)

**Operations:**
1. Validate `AGENTIZE_HOME` is a git worktree
2. Check for uncommitted changes (dirty-tree guard)
3. Resolve default branch from `origin/HEAD`
4. Run `git pull --rebase origin <branch>`
5. Print shell reload instructions on success

**Return codes:**
- `0`: Upgrade successful
- `1`: Not a worktree, dirty tree, or rebase failed

### lol_cmd_project()

GitHub Projects v2 integration.

**Signature:**
```bash
lol_cmd_project <mode> [arg1] [arg2] [arg3]
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

### lol_cmd_claude_clean()

Remove stale project entries from `~/.claude.json`.

**Signature:**
```bash
lol_cmd_claude_clean <dry_run>
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

### lol_cmd_version()

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

## Internal Helpers

### YAML Parsing

Simple YAML parsing for `.agentize.yaml`:
- `read_metadata <key>`: Extract value from project section
- `update_metadata <key> <value>`: Update or add field

### Path Resolution

- All paths converted to absolute before use
- `.claude/` directory search traverses parent directories
- Project root detection via `git rev-parse --show-toplevel`

## Usage Patterns

### Sourcing vs Execution

**Sourced (primary usage):**
```bash
source setup.sh  # Sources src/cli/lol.sh
lol init --name my-project --lang python
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
