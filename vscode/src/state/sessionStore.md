# sessionStore.ts

Plan session persistence and CRUD helper used by the extension backend.

## External Interface

### SessionStore
- `getAppState()`: returns the full AppState with placeholders.
- `getPlanState()`: returns the current PlanState snapshot.
- `createSession(prompt: string)`: creates a new session and persists it.
- `updateSession(id: string, update: Partial<PlanSession>)`: updates a session and persists it.
- `appendSessionLogs(id: string, lines: string[])`: appends log lines with trimming.
- `toggleSessionCollapse(id: string)`: flips the collapsed flag.
- `deleteSession(id: string)`: removes a session.
- `updateDraftInput(value: string)`: persists the draft input text.
- `getSession(id: string)`: returns a single session by id.

## Internal Helpers

### createSessionId()
Generates a unique identifier for a new session.

### deriveTitle(prompt: string)
Builds a readable title from the prompt using a fixed-length slice.

### trimLogs(lines: string[])
Enforces the maximum number of stored log lines per session.
