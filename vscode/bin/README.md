# VS Code Extension Binaries

This folder contains helper executables used by the VS Code extension runtime.

## Organization

- `lol-wrapper.js` bridges the shell-based `lol` CLI into a subprocess-friendly command.
- `lol-wrapper.md` documents the wrapper interface and behavior.
- `render-plan-harness.js` generates a Playwright harness HTML in the active worktree `.tmp/`.
- `render-plan-harness.md` documents harness generation and path resolution.
