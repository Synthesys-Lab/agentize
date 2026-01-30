# test-acw-silent-flag.sh

## Purpose

Validate `acw --silent` behavior for provider stderr suppression and option filtering while preserving acw validation errors.

## Test Cases

### provider_stderr_visible_without_silent
**Purpose**: Ensure provider stderr passes through when `--silent` is not used.
**Setup**: Stub `claude` CLI emits stderr and stdout.
**Expected**: stderr contains provider output and response file is written.

### provider_stderr_suppressed_with_silent
**Purpose**: Ensure provider stderr is suppressed when `--silent` is present.
**Setup**: Stub `claude` CLI emits stderr and stdout.
**Expected**: stderr is empty and response file is written.

### silent_not_forwarded_to_provider
**Purpose**: Ensure `--silent` is not passed to provider arguments.
**Setup**: Stub `claude` logs arguments to a file.
**Expected**: Arguments contain provider options but not `--silent`.

### validation_errors_visible_with_silent
**Purpose**: Ensure acw validation errors remain visible with `--silent`.
**Setup**: Invoke `acw --silent` with missing required args.
**Expected**: stderr includes the validation error and exit code is non-zero.

### completion_includes_silent
**Purpose**: Ensure completion includes `--silent` in `cli-options`.
**Setup**: Invoke `acw --complete cli-options`.
**Expected**: Output includes `--silent`.
