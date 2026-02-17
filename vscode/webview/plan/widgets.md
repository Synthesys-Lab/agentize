# widgets.ts

Widget append helpers for the Plan webview.

## External Interface

### createWidgetHandle(type, id, element)
Creates a widget handle for DOM updates and log routing.

### appendPlainText(sessionId, text)
Appends a `text` widget to the session timeline.

### appendTerminalBox(sessionId, title)
Appends a `terminal` widget and returns a handle that supports:
- `appendLine(line)` to append log output.
- `setCollapsed(collapsed)` to collapse/expand the terminal body.

### appendProgressWidget(sessionId, terminalHandle)
Creates a `progress` widget that listens to terminal output and updates
step indicators and elapsed time.

The returned progress handle also supports `replay(lines, events?)`; when `events`
contains persisted stage/exit timestamps, replay uses those timestamps instead of
`Date.now()` so restored elapsed times remain accurate after reload.

### appendButtons(sessionId, buttons)
Appends a `buttons` widget with per-button enabled/disabled state.

### appendInputWidget(sessionId, config)
Appends an inline `input` widget for refinement focus and wires submit/cancel
callbacks.

### updateButtonState(sessionId, buttonId, state)
Updates button labels and enabled/disabled state within an existing button widget.

## Internal Helpers

### getWidgetContainer(sessionId)
Resolves (or creates) the session timeline container used for widget append operations.

### registerWidget(sessionId, handle)
Stores widget handles in a per-session map for update routing.

### removeWidget(sessionId, widgetId)
Removes a widget node and clears its handle registration when the UI needs to retract
an input widget or obsolete action group.
