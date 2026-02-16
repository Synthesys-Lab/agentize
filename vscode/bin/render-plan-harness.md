# render-plan-harness.js

Generates a standalone HTML harness for Playwright screenshots of the Plan webview.

## External Interface

### Command-line usage
```bash
node vscode/bin/render-plan-harness.js
```

### Output
- Writes `<worktree>/.tmp/plan-dev-harness.html`.
- Logs a repo-root-served URL path (`/trees/<branch>/.tmp/plan-dev-harness.html`) plus resolved style/script paths.

### Path behavior
- Resolves `repoRoot` as the parent of `trees/` when the active worktree is under
  `agentize.git/trees/<branch>/`.
- Writes harness artifacts to the active worktree `.tmp`.
- Resolves asset paths against the active worktree so rendering simulates branch runtime behavior while still being serveable from repo root.

## Internal Helpers

### skeleton template loading
- Reads `vscode/webview/plan/skeleton.html`.
- Replaces `{{SKELETON_ERROR}}` with an empty string in harness mode.
- Falls back to an inline skeleton when the template file is unavailable.

### harness bootstrap
- Injects `window.__INITIAL_STATE__`.
- Mocks `window.acquireVsCodeApi()` with a console-backed `postMessage` implementation.
- Loads the compiled webview script `webview/plan/out/index.js` via module script.
