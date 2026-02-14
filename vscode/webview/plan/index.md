# index.ts

Webview script that renders the Plan session list and handles user input.

## External Interface

### UI Actions
- Creates new Plan sessions and posts `plan/new` to the extension.
- Sends `plan/run`, `plan/toggleCollapse`, `plan/delete`, and `plan/updateDraft` messages.
- Receives `state/replace`, `plan/sessionUpdated`, and `plan/runEvent` messages.
- Deletes confirm that running sessions will be stopped before removal.

### Keyboard Shortcuts
- `Cmd+Enter` (macOS) or `Ctrl+Enter` (Linux/Windows) submits the plan input.

## Internal Helpers

### renderState(appState)
Initial render for all sessions and the draft input.

### updateSession(session)
Updates a single session row without re-rendering the full list.

### appendLogLine(sessionId, line, stream)
Appends a log line with a per-session buffer limit.
