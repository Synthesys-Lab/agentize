# dispatch.sh

Dispatch layer for the `lol` CLI, including help output and version logging.

## External Interface

### lol()

Routes subcommands (including `use-branch`) to their parsers and handles
top-level flags.

**Parameters**:
- `$1`: Subcommand or flag (`upgrade`, `project`, `plan`, `usage`, `--version`, `--complete`, etc.).
- `$@`: Remaining arguments passed to the parser for the selected command.

**Behavior**:
- Validates `AGENTIZE_HOME` before executing commands.
- Emits help text on unknown subcommands.
- Uses `_lol_log_version` for consistent version reporting.

## Internal Helpers

### _lol_log_version()

Writes a stable version banner to stderr using the git tag (or short hash) and
full commit hash from `AGENTIZE_HOME`. This keeps diagnostics consistent across
commands and avoids polluting completion output.
