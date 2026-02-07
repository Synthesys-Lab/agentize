# test-lol-simp-args.sh

Validates `lol simp` argument handling and Python delegation.

## Coverage

- `lol simp` with no args delegates to `python -m agentize.cli simp`.
- `lol simp <file>` forwards the file argument to the Python CLI.
- `lol simp <description>` (non-existent path) forwards as `--focus` to Python CLI.
- `lol simp --focus <description>` forwards the focus description to Python CLI.
- `lol simp --editor` invokes `$EDITOR` and forwards editor content as `--focus`.
- `--editor` and `--focus` are mutually exclusive (error, no delegation).
- `--editor` and positional description are mutually exclusive (error, no delegation).
- Multiple `--focus` flags are rejected (error, no delegation).
- Extra positional arguments are rejected with a usage message and no delegation.
