# test-lol-simp-args.sh

Validates `lol simp` argument handling and Python delegation.

## Coverage

- `lol simp` with no args delegates to `python -m agentize.cli simp`.
- `lol simp <file>` forwards the file argument to the Python CLI.
- Extra positional arguments are rejected with a usage message and no delegation.
