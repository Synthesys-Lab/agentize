# styles.css

Minimal readable styles for the Plan webview UI.

## External Interface

### Layout Classes
- `.plan-root`: top-level layout container.
- `.toolbar`: header actions for New Plan.
- `.session`: container for a single plan session.
- `.session-header`: row with title, status, and actions.
- `.session-body`: contains prompt and logs.
- `.logs`: monospace log display.

### Status Modifiers
- `[data-status="idle"]`, `[data-status="running"]`, `[data-status="success"]`,
  `[data-status="error"]`: status-driven colors and accents.

## Internal Helpers

No internal helpers; this file only provides static styles.
