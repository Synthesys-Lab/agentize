# planViewProvider.ts

Webview view provider that renders the Plan sidebar and routes messages between the
webview UI, session state, and runner.

## External Interface

### PlanViewProvider
- `resolveWebviewView(view: vscode.WebviewView)`: renders HTML, injects initial state,
  and registers the message handler.
- `postState()`: sends a full state replacement to the webview when needed.
- `postSessionUpdate(update: PlanSessionUpdate)`: sends targeted updates for a single session.

### Message Handling
Consumes UI messages:
- `plan/new`
- `plan/run`
- `plan/toggleCollapse`
- `plan/delete`
- `plan/updateDraft`

Emits UI messages:
- `state/replace`
- `plan/sessionUpdated`
- `plan/runEvent`

## Internal Helpers

### buildHtml(webview: vscode.Webview)
Builds the webview HTML with CSP, script/style URIs, and initial state injection.

### handleRunEvent(event: RunEvent)
Transforms runner events into state updates and UI updates (status changes and log lines).

### resolvePlanCwd()
Resolves the default planning working directory as `<workspace>/trees/main`.
