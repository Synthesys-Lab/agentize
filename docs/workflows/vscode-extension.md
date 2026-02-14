# VS Code Extension Workflow

This document describes the Plan-to-Implement workflow exposed by the VS Code extension.
It focuses on the rationale behind the UI and state flow so the behavior stays consistent
across future updates.

## Goals

- Provide a single-click transition from planning to implementation.
- Capture the GitHub issue number as soon as the planner emits it.
- Keep plan and implementation logs visually separate to reduce confusion.

## Plan Session Lifecycle

1. The user creates a Plan session in the Activity Bar panel.
2. The extension launches `lol plan` via the CLI wrapper and streams stdout/stderr into
   the session log buffer.
3. The session status transitions through `running` to `success` or `error`.

## Issue Number Capture

The planner emits lines such as `Created placeholder issue #N` or a GitHub issue URL.
The extension scans stdout/stderr lines in real time and stores the first matching issue
number on the session. Capturing the issue number during execution ensures the UI can
surface the Implement action immediately after the plan completes.

## Implementation Launch

When a plan succeeds and an issue number exists, the UI displays an Implement button in
that session header. Clicking it launches `lol impl <issue-number>` and tracks the run
status separately from the plan. The UI disables the button while the implementation run
is active to prevent overlapping runs.

## Log Separation

Implementation output is streamed into a dedicated Implementation Log panel. Keeping the
plan and implementation logs separate avoids mixing the planner transcript with code
changes, which makes it easier to scan each phase independently.
