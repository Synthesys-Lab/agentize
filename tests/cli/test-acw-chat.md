# test-acw-chat.sh

## Purpose

End-to-end tests for `acw` chat session functionality (`--chat` and `--chat-list`).

## Coverage

### Session Creation
- `--chat` without session ID creates a new session file
- New session prints session ID to stderr
- Session file has valid YAML front matter (provider, model, created)

### Session Continuation
- `--chat <id>` continues an existing session
- Session history is prepended to input
- New turn is appended to session file

### Error Handling
- Invalid session ID (non-base62 or wrong length) returns exit code 5
- Missing session file returns exit code 5
- Malformed session file returns exit code 5

### Stdout Capture
- `--chat --stdout` captures and emits assistant output
- Captured output is also appended to session file

### Stderr Sidecar (--chat --stdout)
- Provider stderr is written to `<session-id>.stderr` sidecar file
- Stdout remains clean (contains only model output)
- Empty sidecar files are removed after provider exits

### Session Listing
- `--chat-list` outputs session IDs with metadata
- `--chat-list` exits 0 without requiring provider args
- Empty session directory outputs nothing

## Test Data

All test fixtures are created on-the-fly within the test script to ensure
isolation. No pre-existing session files are required.
