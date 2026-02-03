# dispatch.sh

Dispatch layer for the `wt` CLI, including command routing and version logging.

## External Interface

### wt()

Routes subcommands to their handlers and manages help/error output.

**Parameters**:
- `$1`: Subcommand or flag (`clone`, `init`, `help`, `--complete`, etc.).
- `$@`: Remaining arguments passed to the handler.

**Behavior**:
- Logs the version banner for help and unknown commands via `_wt_log_version`.
- Keeps completion output clean by skipping logging for `--complete`.
- Delegates to `cmd_*` handlers for command execution.

## Internal Helpers

### _wt_log_version()

Writes the version banner to stderr in the format
`[agentize] <branch> @<short-hash>`. The branch and short hash are resolved from
the current git worktree root and fall back to `unknown` when git metadata is
unavailable. Accepts the current command to suppress output during `--complete`.
