# dispatch.sh

Dispatch layer for the `acw` CLI, including help output, validation, and provider routing.

## External Interface

### acw()

Entry point for the Agent CLI Wrapper.

**Parameters**:
- `$1`: Provider name or top-level flag (`--help`, `--complete`).
- `$2`: Model identifier for the provider.
- `$3`: Input file path.
- `$4`: Output file path.
- `$@`: Provider options.

**Behavior**:
- Emits usage text for `--help` and returns completion values for `--complete`.
- Validates required arguments, provider name, and input/output paths before dispatch.
- Consumes `--silent` from the option list to suppress provider stderr output while keeping acw validation errors visible.
- Forwards remaining options to the provider invocation and returns the provider exit code.

## Internal Helpers

### _acw_usage()

Prints a stable usage banner describing arguments, options, and exit codes.
