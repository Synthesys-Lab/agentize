# index.ts

Webview script that renders the Plan session list and handles user input.

## File Organization

- `index.ts`: Webview entry point that renders sessions, handles input, and posts messages.
- `utils.ts`: Pure rendering and parsing helpers for steps, links, and issue extraction.
- `types.ts`: Message shapes exchanged with the extension host.
- `styles.css`: Plan tab styling.

## External Interface

### UI Actions
- Creates new Plan sessions and posts `plan/new` to the extension.
- Sends `plan/toggleCollapse`, `plan/delete`, and `plan/updateDraft` messages.
- Sends `plan/impl` when the Implement button is pressed for a completed plan.
- Sends `plan/toggleImplCollapse` when the implementation log panel is collapsed or expanded.
- Sends `plan/refine` when the inline refinement textbox is submitted (Cmd+Enter / Ctrl+Enter).
- Sends `link/openExternal` and `link/openFile` for clickable links in logs.
- Deletes are immediate; running sessions are stopped by the extension host.

### Keyboard Shortcuts
- `Cmd+Enter` (macOS) or `Ctrl+Enter` (Linux/Windows) submits the plan input.

## Internal Helpers

### ensureSessionNode(session)
Builds the session DOM using a sequential append pattern so the visual order is explicit:

1. Create the session container and header.
2. Create the session body.
3. Append the prompt text.
4. Append step indicators.
5. Append the raw console log panel.
6. Append the implementation log panel.
7. Append refinement thread and composer.

### renderState(appState)
Initial render for all sessions and the draft input.

### updateSession(session)
Updates a single session row without re-rendering the full list.

### appendLogLine(sessionId, line, stream)
Appends a log line with a per-session buffer limit. Parses stderr lines for stage progress and updates step indicators.

### appendImplLogLine(sessionId, line, stream)
Appends a log line to the implementation log buffer and keeps the implementation log panel scrolled.

### Step Progress Indicators

Step indicators are rendered above the raw logs box by parsing stderr lines matching the pattern:
```
Stage N/5: Running {name} ({provider}:{model})
Stage M-N/5: Running {name} ({provider}:{model})  // parallel stages
```

Running steps display animated dots cycling from 1 to 3 using CSS `@keyframes`. When a step completes, the elapsed time is calculated from the start timestamp and displayed as "done in XXs".

### Collapsible Raw Console Log

The raw console log box can be collapsed/expanded independently of the session collapse. Clicking the toggle button updates the local state; the collapse state is maintained in the webview and persists across state updates.

### Implement Button + Implementation Logs

When a plan finishes successfully and an issue number has been captured, the session header shows an Implement button.
Clicking it triggers `plan/impl` with the issue number, and a separate "Implementation Log" panel streams the output.
The button is disabled while the implementation run is active.
If the session `issueState` is `closed`, the button text changes to "Closed" and stays disabled to prevent
implementation runs on closed issues.

### Issue Number Extraction (UI)

The webview parses incoming log lines for:
- `Created placeholder issue #N`
- `https://github.com/<owner>/<repo>/issues/N`

This acts as a UI-side fallback to surface the Implement button even if the extension state has
not yet persisted the issue number.

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

`StepState` is defined in `utils.ts` alongside the parsing and rendering helpers that build the indicator UI.
