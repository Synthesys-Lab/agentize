# styles.css

Minimal readable styles for the Plan webview UI.

## External Interface

### Layout Classes
- `.plan-root`: top-level layout container.
- `.plan-skeleton`, `.plan-skeleton-title`, `.plan-skeleton-subtitle`, `.plan-skeleton-error`: static boot UI rendered before the webview script hydrates.
- `.toolbar`: header actions for New Plan.
- `.session`: container for a single plan session.
- `.session-header`: row with title, status, and actions.
- `.session-body`: contains prompt and logs.
- `.logs`: monospace log display.
- `.hidden`: utility class to hide optional UI elements.
- `.impl-button`: primary action for starting implementation runs.
- `.impl-button.closed`: disabled styling when the linked issue is closed.
- `.impl-logs-box`: container for implementation logs and header.
- `.impl-logs-header`, `.impl-logs-toggle`, `.impl-logs-title`, `.impl-logs-body`: implementation log panel chrome.
- `#plan-textarea`: uses border-box sizing to keep padding within the panel.
- `.refine`: action button for revealing the inline refinement textbox on completed sessions.

### Status Modifiers
- `[data-status="idle"]`, `[data-status="running"]`, `[data-status="success"]`,
  `[data-status="error"]`: status-driven colors and accents.

## Internal Helpers

No internal helpers; this file only provides static styles.

### Animation

- `.session-body` uses CSS transitions to keep the collapse/expand interaction smooth while
  preserving layout flow for the header area.
- Transitioned properties:
  - `max-height`: 0 ↔ 2000px to accommodate variable content without JS measurement.
  - `margin-top`: 0 ↔ 10px to collapse spacing cleanly.
- Timing: `0.25s ease-out` to match the raw logs collapse cadence used elsewhere in the view.
