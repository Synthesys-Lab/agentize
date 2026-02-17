# index.ts

Append-only webview controller for the Plan tab.

## Design Intent

The webview no longer renders legacy Plan/Implementation sections inside each session.
Each session body is a pure widget timeline driven by `widget/append` and `widget/update`
messages from the extension host.

## File Organization

- `index.ts`: Session shell rendering, widget hydration, and message routing.
- `widgets.ts`: Widget DOM constructors and handle registry.
- `utils.ts`: Link rendering and stage parsing used by terminal/progress widgets.
- `types.ts`: Webview message and widget shape definitions.
- `styles.css`: Visual style for session shells and widgets.

## External Interface

### Outgoing Messages
- `plan/new`, `plan/updateDraft`, `plan/toggleCollapse`, `plan/delete`
- `plan/impl` from action widgets
- `plan/refine` from inline refine input widget submission
- `plan/rerun` from rerun action widgets
- `plan/stop` from the Plan terminal stop control
- `link/openExternal` and `link/openFile` from terminal link clicks

### Incoming Messages
- `state/replace`: full state hydration
- `plan/sessionUpdated`: session header/state refresh
- `widget/append`: append a widget by id and type
- `widget/update`: mutate a widget (`appendLines`, `replaceButtons`, `complete`, `metadata`)

## Refine Flow

When a `Refine` action button is clicked, the webview appends a local `input` widget in the
session timeline. Submitting with Cmd/Ctrl+Enter sends `plan/refine` with a generated `runId`.
Esc cancels and removes the input widget.

## Widget Hydration

On state/session refresh, the webview replays `session.widgets` in creation order. Existing
handles are updated in-place when possible; missing handles are appended. This keeps recovered
state and live updates aligned without legacy duplicated UI sections.

For progress widgets, hydration now prefers persisted `metadata.progressEvents` timestamps
over raw log replay, so elapsed stage timings remain stable across reloads.

## Process Control

The plan terminal header includes a stop control that posts `plan/stop`. The button is
only surfaced when the session status indicates an active plan run, and the UI disables
it immediately to prevent repeated stop requests.
