# index.ts

Webview script that renders the Plan session list and handles user input.

## File Organization

- `index.ts`: Webview entry point that renders sessions, handles input, and posts messages.
- `widgets.ts`: Widget append helpers and widget handle routing.
- `utils.ts`: Pure rendering and parsing helpers for steps, links, and issue extraction.
- `types.ts`: Message shapes exchanged with the extension host.
- `styles.css`: Plan tab styling.

## External Interface

### UI Actions
- Creates new Plan sessions and posts `plan/new` to the extension.
- Sends `plan/toggleCollapse`, `plan/delete`, and `plan/updateDraft` messages.
- Sends `plan/impl` when the Implement button is pressed for a completed plan.
- Sends `plan/refine` when the inline refinement textbox is submitted (Cmd+Enter / Ctrl+Enter).
- Sends `link/openExternal` and `link/openFile` for clickable links in logs.
- Sends `widget/append` and `widget/update` events into the session timeline when user actions require
  new UI widgets (input widgets, button groups, progress widgets).

### Keyboard Shortcuts
- `Cmd+Enter` (macOS) or `Ctrl+Enter` (Linux/Windows) submits the plan input.
- `Cmd+Enter` / `Ctrl+Enter` submits the refinement input widget.
- `Esc` closes an inline refinement input widget without submitting.

## Internal Helpers

### ensureSessionNode(session)
Creates a session container and a widget timeline body. Widgets are appended as the session
progresses, keeping the visual order explicit and avoiding pre-created DOM structure.

### renderState(appState)
Initial render for all sessions and the draft input.

### updateSession(session)
Updates a single session row without re-rendering the full list, and replays the widget timeline
state for that session.

### handleWidgetAppend / handleWidgetUpdate
Respond to widget append or update messages from the extension host, create widget DOM nodes, and
update widget state/handles.

### appendLogLine / appendImplLogLine
Route stdout/stderr lines into the active terminal widget for a session, preserving the maximum
log buffer and emitting link-rendered markup.

## Collapsible Raw Console Log

Each session has a collapsible raw console log widget that captures all stdout/stderr output.
The log box can be expanded/collapsed via the toggle button in its header, and the collapsed
state is persisted per-session.

## Step Progress Indicators

Progress widgets listen to terminal output lines that match:
```
Stage N/5: Running {name} ({provider}:{model})
Stage M-N/5: Running {name} ({provider}:{model})  // parallel stages
```

Running steps display animated dots cycling from 1 to 3 using CSS `@keyframes`. When a step
completes, the elapsed time is calculated from the start timestamp and displayed as "done in XXs".

## Inline Refinement Input

Refinement input is represented by an `input` widget appended when Refine is clicked. The widget
is removed on Esc or after successful submission, and the session transitions into a refining phase.

## Implementation Completion Actions

When implementation exits with code 0, a View PR button is appended. When the exit code is non-zero,
a Re-implement button is appended to the widget timeline instead.

## Closed Issue Button State

When a plan's associated GitHub issue is closed, the Implement button displays "Closed" and is
disabled to prevent further implementation attempts. The issue state is checked via the GitHub CLI
and cached per session.

## Interactive Links

GitHub issue URLs (`https://github.com/.../issues/N`) and local markdown file paths (`.tmp/*.md`) are
detected via regex and rendered as clickable links. Clicking sends:
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

`StepState` is defined in `utils.ts` alongside the parsing and rendering helpers that build the
indicator UI.
