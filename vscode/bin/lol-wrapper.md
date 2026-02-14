# lol-wrapper.js

Node.js wrapper that exposes the shell-based `lol` CLI as a subprocess-friendly
command for the VS Code extension.

## External Interface

### Command-line usage
```bash
node vscode/bin/lol-wrapper.js <lol-subcommand> [args...]
```

**Parameters**:
- `<lol-subcommand>`: any supported `lol` subcommand (for example `plan`).
- `args...`: forwarded to the `lol` command without modification.

**Environment**:
- Resolves the repository root relative to the wrapper location.
- Sources `setup.sh` from the repository root when available.
- Falls back to sourcing `src/cli/lol.sh` when `setup.sh` is missing.
- Ensures `AGENTIZE_HOME` is set to the repository root if it is not already set.

**Exit behavior**:
- Forwards the exit code from the `lol` command.
- Returns a non-zero exit code when the wrapper cannot start the shell process.

## Internal Helpers

### escapeForDoubleQuotes(value: string)
Escapes backslashes and double quotes so paths can be safely interpolated into
the `bash -lc` command string.

### bash command composition
Builds a single `bash -lc` string that exports `AGENTIZE_HOME`, sources the setup
script, and runs `lol "$@"` with arguments forwarded as positional parameters.

### subprocess lifecycle
Spawns `bash` with inherited stdio and forwards the child exit status, emitting a
clear error if the shell fails to start.
