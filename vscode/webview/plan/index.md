# index.ts

Webview script that renders the Plan session list and handles user input.

## External Interface

### UI Actions
- Creates new Plan sessions and posts `plan/new` to the extension.
- Sends `plan/toggleCollapse`, `plan/delete`, and `plan/updateDraft` messages.
- Sends `link/openExternal` and `link/openFile` for clickable links in logs.
- Deletes are immediate; running sessions are stopped by the extension host.

### Keyboard Shortcuts
- `Cmd+Enter` (macOS) or `Ctrl+Enter` (Linux/Windows) submits the plan input.

## Internal Helpers

### renderState(appState)
Initial render for all sessions and the draft input.

### updateSession(session)
Updates a single session row without re-rendering the full list.

### appendLogLine(sessionId, line, stream)
Appends a log line with a per-session buffer limit. Parses stderr lines for stage progress and updates step indicators.

### Step Progress Indicators

Step indicators are rendered above the raw logs box by parsing stderr lines matching the pattern:
```
Stage N/5: Running {name} ({provider}:{model})
Stage M-N/5: Running {name} ({provider}:{model})  // parallel stages
```

Running steps display animated dots cycling from 1 to 3 using CSS `@keyframes`. When a step completes, the elapsed time is calculated from the start timestamp and displayed as "done in XXs".

### Collapsible Raw Console Log

The raw console log box can be collapsed/expanded independently of the session collapse. Clicking the toggle button updates the local state; the collapse state is maintained in the webview and persists across state updates.

### Interactive Links

GitHub issue URLs (`https://github.com/.../issues/N`) and local markdown file paths (`.tmp/*.md`) are detected via regex and rendered as clickable links. Clicking sends:
- `link/openExternal` with the URL for GitHub links
- `link/openFile` with the path for local markdown files

## Step State Tracking

```typescript
interface StepState {
  stage: number;           // Stage number (1-5)
  endStage?: number;      // End stage for parallel stages (M-N)
  total: number;          // Total stages (5)
  name: string;           // Agent name (e.g., "understander")
  provider: string;       // Provider (e.g., "claude")
  model: string;          // Model (e.g., "sonnet")
  status: 'pending' | 'running' | 'completed';
  startTime: number;      // Timestamp when step started
  endTime?: number;       // Timestamp when step completed
}
```
