# test-session-append.js

Playwright soft test flow for the Plan webview session append behavior.

## External Interface

### Command
```bash
node vscode/test/playwright/test-session-append.js
```

### Behavior
- Generates `.tmp/plan-dev-harness.html` via `vscode/bin/render-plan-harness.js`.
- Serves the repository root so the harness can load web assets the same way as opening
  `agentize.git` in VS Code.
- Executes a full soft flow:
  1. Click `New Plan`.
  2. Fill `test prompt, end this asap`.
  3. Submit with `Cmd+Enter` (or `Ctrl+Enter` on non-macOS).
  4. Wait for simulated planner completion and verify action buttons are enabled.
  5. Click `Refine`, submit the same prompt, simulate refine run, and wait for completion.
- Dumps screenshots for every key step into worktree `.tmp` with deterministic names:
  - `.tmp/test-session-append-1.png`
  - `.tmp/test-session-append-2.png`
  - ...
- Writes a soft-check report to `.tmp/test-session-append-report.txt`.

## Soft Test Design

The script is intentionally non-strict for UI semantics:
- It records warnings in the report instead of hard-failing on every UI mismatch.
- It still fails on hard runtime blockers (missing Playwright, server startup failure,
  page bootstrap failure).

This design keeps the flow debuggable in CI while preserving human review of screenshots.

## Runtime Prerequisites

- `playwright` must be available in `vscode/node_modules`.
- If missing, install with:
```bash
npm --prefix vscode install --save-dev playwright
```
