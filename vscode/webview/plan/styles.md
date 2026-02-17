# styles.css

Minimal readable styles for the Plan webview UI.

## External Interface

### Layout Classes
- `.plan-root`: top-level layout container.
- `.plan-skeleton`, `.plan-skeleton-title`, `.plan-skeleton-subtitle`, `.plan-skeleton-error`: static boot UI rendered before the webview script hydrates.
- `.toolbar`: header actions for New Plan.
- `.session`: container for a single plan session.
- `.session-header`: row with title, status, and actions.
- `.session-body`: contains the widget timeline for a session.
- `.widget`: base class for appended widgets.
- `.widget-terminal`: terminal widget container.
- `.terminal-stop-button`: stop control aligned to the right edge of the terminal header.
- `.widget-progress`: step progress indicator widget.
- `.widget-buttons`: action button groups.
- `.widget-input`: inline refinement input widget.
- `.widget-status`: compact status badge widget.
- `.logs`: monospace log display.
- `.hidden`: utility class to hide optional UI elements.
- `.button-disabled`: grayed-out button state.
- `#plan-textarea`: uses border-box sizing to keep padding within the panel.

### Status Modifiers
- `[data-status="idle"]`, `[data-status="running"]`, `[data-status="success"]`,
  `[data-status="error"]`: status-driven colors and accents.

## Internal Helpers

No internal helpers; this file only provides static styles.

### Animation

- `.widget` uses CSS transitions to keep the append animation lightweight while
  preserving layout flow for the header area.
- `.widget-progress` uses `@keyframes` for the loading dot indicator.
