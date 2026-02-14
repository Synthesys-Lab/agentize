# planViewProvider.ts

Webview view provider that renders the Plan Activity Bar panel and routes messages between the
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
- `link/openExternal` - Opens GitHub issue URLs in default browser
- `link/openFile` - Opens local markdown files in VSCode editor

`plan/delete` stops an in-flight session before removing it from storage.

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
Resolves the planning working directory.

- If an opened workspace folder contains `trees/main`, uses `<workspace>/trees/main`.
- Otherwise, falls back to the workspace root when it appears to be an Agentize worktree.

### Link Handling

The provider validates and handles link opening requests from the webview:

**`isValidGitHubUrl(url: string): boolean`**
Validates GitHub issue URLs using the pattern `^https://github\.com/[^/]+/[^/]+/issues/\d+$`.

**`openLocalFile(filePath: string): Promise<void>`**
Resolves local file paths relative to the workspace root and opens them in the VSCode editor using `vscode.workspace.openTextDocument()` and `vscode.window.showTextDocument()`.
