# unifiedViewProvider.ts

Unified webview provider that renders a single Activity Bar view with tab navigation for
Plan, Worktree, and Settings. It routes plan-related messages between the webview UI,
session store, and runner, and handles local file opening requests from webview links.

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
- `plan/stop`
- `plan/refine`
- `plan/impl`
- `plan/rerun`
- `plan/toggleCollapse`
- `plan/delete`
- `plan/updateDraft`
- `plan/view-plan`
- `plan/view-issue`
- `plan/view-pr`
- `link/openExternal` (GitHub issue URLs)
- `link/openFile` (local markdown paths)

Emits UI messages:
- `state/replace`
- `plan/sessionUpdated`
- `widget/append`
- `widget/update`

`plan/refine` starts a refinement run for the selected session, using the captured
issue number and focus prompt from the webview. `plan/impl` validates the issue state
before launching implementation output into terminal widgets. `plan/rerun` reuses the
stored rerun context to retry failed `plan`/`refine`/`impl` runs without requiring
manual prompt re-entry.
`plan/stop` sends a stop request to whichever command is currently running for the
session (`plan`, `refine`, or `impl`) and logs the request immediately.
Final session state changes now wait for the real runner `exit` event, which prevents
the UI from presenting a completed stop before the process has actually terminated.
`plan/view-issue` resolves the canonical GitHub issue URL via `gh issue view` and opens it.

## Internal Helpers

### buildHtml(webview: vscode.Webview)
Builds the unified HTML shell with a tab strip and three panels:
- `#plan-root` loads the compiled Plan webview script and initial state.
- `#worktree-root` loads the Worktree placeholder script.
- `#settings-root` loads the Settings webview script.

The method assembles CSP-safe script/style URIs and injects a shared bootloader that
surfaces asset or runtime errors through each panel's skeleton status line.
The tab strip uses a sticky, opaque background so panel content does not bleed through
while scrolling.
Inactive tabs intentionally use a lighter muted label color to keep focus emphasis on
the active tab.

Tab Styling:
The `.unified-tab` class uses flexbox with `flex: 1` to distribute equal width to all tabs,
ensuring the Plan, Worktree, and Settings tabs maintain consistent proportions regardless
of label text length. Tab labels are centered via `text-align: center`. To prevent layout
issues in narrow sidebars, overflow protection is applied: `white-space: nowrap` prevents
text wrapping, `overflow: hidden` clips excess content, and `text-overflow: ellipsis`
displays an ellipsis ("...") when labels are truncated due to insufficient space.

### buildPlanSkeleton(hasAssets: boolean)
Loads `webview/plan/skeleton.html` and injects an asset-missing banner when compiled
assets are not present on disk.

### buildPlaceholderSkeleton(title: string, statusId: string, hasAssets: boolean)
Creates a lightweight skeleton for Worktree and Settings panels while reusing the
Plan styling tokens.

### resolveBackendForRun()
Searches for `planner.backend` using the standard `.agentize.local.yaml` precedence
(repo → `$AGENTIZE_HOME` → `$HOME`) and returns the first valid backend spec for
implementation runs.

### handleRunEvent(event: RunEvent)
Transforms runner events into session updates and widget updates, routing stdout/stderr
into terminal widgets and capturing issue numbers from output. The handler also persists
progress stage/exit timestamps in progress-widget metadata (`progressEvents`) so elapsed
timing can be reconstructed accurately after reload.

### Action Row State
`buildActionButtons` uses two states:
- While `implement`, `refine`, or `rerun` is running, the row is locked to that single action button (`rerun` shows `Rerunning...`).
- After the run exits, the row always returns to the five core buttons:
  `View Plan`, `View Issue`, `Implement`, `Refine`, and `Rerun`.

When a direct `refine` run exits, the in-place running button is archived as a disabled
`Refined` (or `Refine failed`) marker, and a fresh five-button action row is appended
to the end of the session timeline so follow-up actions stay near the most recent output.
Direct `implement` runs follow the same append behavior, archiving the running button as
`Implemented` (or `Implement failed`) before appending the fresh action row.
`rerun` follows the same archival pattern: the active rerun row is frozen as `Reran`
or `Rerun failed`, and a fresh core action row is appended at the timeline tail.

`Rerun` is always rendered in the core row and is enabled only when the latest related
run exit code is non-zero; otherwise it is disabled. A successful implementation run
with a captured PR URL appends `View PR` so users can open the generated pull request.

### resolvePlanCwd()
Resolves the working directory for Plan/Implementation runs by preferring the
`trees/main` layout and falling back to an Agentize worktree root when needed.

### Link Handling
- `isValidGitHubUrl(url: string)`: validates GitHub issue URLs.
- `openLocalFile(filePath: string, options?)`: resolves relative paths from workspace
  roots, expands `~/...`, optionally creates missing files, and opens in the current
  editor group as a non-preview tab.

### Issue State Validation
`checkIssueState(issueNumber: string)` uses `gh issue view` to guard implementation
runs when a GitHub issue is closed and records the result on the session.
