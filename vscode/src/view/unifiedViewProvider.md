# unifiedViewProvider.ts

Unified webview provider that renders a single Activity Bar view with tab navigation for
Plan, Worktree, and Settings. It routes plan-related messages between the webview UI,
session store, and runner while keeping auxiliary panels in the same webview.

## External Interface

### UnifiedViewProvider
- `static viewType`: View ID (`agentize.unifiedView`) registered in the extension host.
- `resolveWebviewView(view: vscode.WebviewView)`: renders the tabbed HTML, injects
  initial state for the Plan panel, and wires message + visibility handlers.

### Webview Messages
Consumes UI messages:
- `webview/ready`
- `plan/new`
- `plan/run`
- `plan/refine`
- `plan/impl`
- `plan/toggleCollapse`
- `plan/toggleImplCollapse`
- `plan/delete`
- `plan/updateDraft`
- `link/openExternal` (GitHub issue URLs)
- `link/openFile` (local markdown paths)

Emits UI messages:
- `state/replace`
- `plan/sessionUpdated`
- `plan/runEvent`

`plan/refine` starts a refinement run for the selected session, using the captured
issue number and focus prompt from the webview. `plan/impl` validates the issue state
before launching implementation logs in a separate buffer.

## Internal Helpers

### buildHtml(webview: vscode.Webview)
Builds the unified HTML shell with a tab strip and three panels:
- `#plan-root` loads the compiled Plan webview script and initial state.
- `#worktree-root` loads the Worktree placeholder script.
- `#settings-root` loads the Settings placeholder script.

The method assembles CSP-safe script/style URIs and injects a shared bootloader that
surfaces asset or runtime errors through each panel's skeleton status line.
The tab strip uses a sticky, opaque background so panel content does not bleed through
while scrolling.

### buildPlanSkeleton(hasAssets: boolean)
Loads `webview/plan/skeleton.html` and injects an asset-missing banner when compiled
assets are not present on disk.

### buildPlaceholderSkeleton(title: string, statusId: string, hasAssets: boolean)
Creates a lightweight skeleton for Worktree and Settings panels while reusing the
Plan styling tokens.

### handleRunEvent(event: RunEvent)
Transforms runner events into session updates and webview messages, separating Plan
and Implementation log streams and capturing issue numbers from output.

### resolvePlanCwd()
Resolves the working directory for Plan/Implementation runs by preferring the
`trees/main` layout and falling back to an Agentize worktree root when needed.

### Link Handling
- `isValidGitHubUrl(url: string)`: validates GitHub issue URLs.
- `openLocalFile(filePath: string)`: resolves paths relative to the workspace root and
  opens the file in the VS Code editor.

### Issue State Validation
`checkIssueState(issueNumber: string)` uses `gh issue view` to guard implementation
runs when a GitHub issue is closed and records the result on the session.
