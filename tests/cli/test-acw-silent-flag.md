# test-acw-silent-flag.sh

## Purpose

Validate the `acw --silent` behavior for suppressing provider stderr while keeping acw validation errors visible.

## Test Coverage

### Provider stderr passthrough (baseline)

- **Setup**: Stub `claude` binary writes to stdout and stderr.
- **Action**: Invoke `acw` without `--silent`.
- **Expected**: Provider stderr appears in the captured stderr output, and the response file is written.

### Provider stderr suppression

- **Setup**: Same stub `claude` binary.
- **Action**: Invoke `acw` with `--silent`.
- **Expected**: No stderr output from the provider, response file contains provider stdout.

### Reserved option filtering

- **Setup**: Stub `claude` logs its argv to a file.
- **Action**: Invoke `acw` with `--silent` and a provider option.
- **Expected**: `--silent` is absent from argv, other options remain.

### acw validation errors remain visible

- **Setup**: Call `acw` with an unknown provider and `--silent`.
- **Action**: Capture stderr output.
- **Expected**: Unknown-provider error text is still emitted.

### Completion update

- **Setup**: Run `acw --complete cli-options`.
- **Expected**: Output includes `--silent`.
