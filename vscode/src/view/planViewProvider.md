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
- `plan/refine`
- `plan/impl`
- `plan/toggleCollapse`
- `plan/toggleImplCollapse`
- `plan/delete`
- `plan/updateDraft`
- `link/openExternal` - Opens GitHub issue URLs in default browser
- `link/openFile` - Opens local markdown files in VSCode editor

`plan/refine` collects refinement focus inline in the session UI (webview) and starts a refinement run within the same session. The issue number is captured from the plan output and forwarded by the webview.

`plan/delete` stops an in-flight session before removing it from storage.
`plan/impl` starts an implementation run for the captured issue number and stores output in a
separate implementation log buffer. Before starting implementation, the provider validates
the GitHub issue state and blocks the run if the issue is closed.

Emits UI messages:
- `state/replace`
- `plan/sessionUpdated`
- `plan/runEvent`

## Internal Helpers

### buildHtml(webview: vscode.Webview)
Builds the webview HTML with CSP, script/style URIs, and initial state injection.

The provider loads the compiled webview script `webview/plan/out/index.js` (built from
`webview/plan/index.ts`) because webviews execute JavaScript only.

The HTML includes a small static skeleton inside `#plan-root` so the view never appears
as a totally blank panel when scripts fail to load or are blocked. The skeleton markup
is loaded from `webview/plan/skeleton.html` so VS Code runtime rendering and standalone
harness rendering share the same template. The provider checks for the presence of
compiled webview assets on disk and emits diagnostic output to the extension OutputChannel
when they are missing.

The webview script is loaded via a tiny inline bootloader so the view can surface
`onerror` and other runtime errors in the skeleton status line rather than failing
silently.

The initial state blob escapes `<`, `U+2028`, and `U+2029` to keep the inline bootstrap
script resilient to user-provided content stored in the session state.

### handleRunEvent(event: RunEvent)
Transforms runner events into state updates and UI updates (status changes and log lines).
Plan events update `status` and `logs`; implementation events update `implStatus` and `implLogs`.
Issue numbers are extracted in real time from stdout/stderr lines and persisted on the session.

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

### Issue Extraction
Plan stdout/stderr lines are scanned for:
- `Created placeholder issue #N`
- `https://github.com/<owner>/<repo>/issues/N`

When a match is found, `issueNumber` is stored on the session and pushed to the webview.

### Issue State Validation

When the Plan view becomes visible, the provider checks the GitHub issue state (via `gh issue view`)
for sessions with an issue number and stores the resulting `issueState` on the session. The same check
runs immediately before starting an implementation run. A closed issue blocks implementation and keeps
the button disabled in the UI. If the `gh` CLI check fails, the provider records `unknown` and allows
implementation to proceed.
