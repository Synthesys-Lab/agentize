# Playwright Soft Tests

This folder contains Playwright-based soft UI flow scripts for the VS Code webview.

## Organization

- `test-session-append.js`: simulates Plan -> Refine append flow and dumps deterministic screenshots into worktree `.tmp`.
- `test-session-append.md`: documents the script behavior, flow contract, and runtime prerequisites.

## Scope

These scripts are designed for visual behavior validation with screenshot artifacts and soft checks.
They intentionally avoid strict pixel assertions so humans can inspect UI intent.
