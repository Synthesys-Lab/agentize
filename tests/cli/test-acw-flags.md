# test-acw-flags.sh

## Purpose

Validate `acw` flag behavior for `--editor`, `--stdout`, and file-mode stderr capture.

## Test Cases

### editor_unset
**Purpose**: `--editor` fails when `EDITOR` is unset.
**Expected**: Non-zero exit with message mentioning `EDITOR`.

### editor_empty_content
**Purpose**: `--editor` rejects whitespace-only content.
**Expected**: Non-zero exit mentioning empty content.

### editor_success
**Purpose**: `--editor` uses editor content as input.
**Expected**: Output file contains editor content.

### stdout_merges_stderr
**Purpose**: `--stdout` merges provider stderr into stdout.
**Expected**: Captured output includes prompt content and `stub-stderr`.

### file_mode_stderr_sidecar
**Purpose**: File mode captures provider stderr in `<output-file>.stderr`.
**Expected**: Sidecar file contains `stub-stderr`, terminal stderr is quiet.

### file_mode_empty_stderr_cleanup
**Purpose**: Empty stderr does not leave a sidecar file.
**Expected**: `<output-file>.stderr` is removed when provider writes no stderr.

### stdout_output_file_rejected
**Purpose**: `--stdout` rejects an output-file positional argument.
**Expected**: Non-zero exit mentioning stdout.
