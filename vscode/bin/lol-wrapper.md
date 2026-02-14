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

### resolveRepoRoot()
Derives the repository root by walking up from `vscode/bin/` so the wrapper can
locate `setup.sh` and CLI sources.

### buildShellCommand(args: string[])
Constructs a bash command that exports `AGENTIZE_HOME`, sources the setup script,
and invokes `lol` with shell-escaped arguments.

### spawnBash(command: string)
Spawns `bash -lc` with inherited stdio and propagates the child process exit code.
