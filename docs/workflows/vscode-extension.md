# VS Code Extension Workflow

This document describes the Plan-to-Implement workflow exposed by the VS Code extension.
It focuses on the rationale behind the UI and state flow so the behavior stays consistent
across future updates.

## Goals

- Present Plan, Implementation, and Refinement output as an append-only timeline of widgets.
- Keep user actions mutually exclusive so only one active phase can run at a time.
- Preserve a lightweight UI model that is easy to extend without introducing new frameworks.
- Capture issue numbers early so downstream actions remain frictionless.

## Widget-Based Session Model

Each session maintains an ordered list of widgets. Widgets are appended as the session
progresses, rather than being pre-created. This keeps the UI layout explicit and allows
different phases to reuse the same widget types.

Widget types include:
- `text`: short status or prompt summaries.
- `terminal`: titled terminal boxes that accept appended log lines via a handle.
- `progress`: stage indicator widgets that listen to terminal output and track elapsed time.
- `buttons`: action groups (Plan, Implement, Refine, View Plan, View PR, Re-implement).
- `input`: inline input widgets for refinement focus.
- `status`: compact status badges for phase transitions.

Terminal widgets expose handles so subsequent updates can target the correct widget without
rebuilding the DOM. Progress widgets subscribe to terminal handles and update themselves
when stage lines are detected.

## Session Phases

Sessions track a phase string to coordinate UI actions:

1. `idle`: session exists but no plan has started.
2. `planning`: the plan run is executing.
3. `plan-completed`: the plan run finished (success or error), actions are available.
4. `refining`: refinement run is active.
5. `implementing`: implementation run is active.
6. `completed`: implementation run finished.

Phase changes drive button state updates so that Refine and Implement are mutually exclusive
and only enabled at appropriate times.

## Process Control

During an active plan run, the terminal header exposes a Stop control that posts a
`plan/stop` message. The extension terminates the running plan process, records a stop
marker in the plan log, and marks the session as `error` with phase `plan-completed` so
the action row returns immediately while keeping Implement disabled for interrupted runs.

## Issue Number Capture

The planner emits lines such as `Created placeholder issue #N` or a GitHub issue URL.
The extension scans stdout/stderr lines in real time and stores the first matching issue
number on the session. Capturing the issue number during execution ensures the UI can
surface the Implement and View PR actions immediately after the plan completes.

When a plan emits a local markdown path (for example, `.tmp/issue-928.md`), the UI
surfaces a View Plan button that opens the file inside the workspace.

## Refinement Flow

When a plan finishes, the user can initiate a refinement run. Clicking Refine appends an
inline input widget. Submitting via Cmd+Enter / Ctrl+Enter starts refinement and appends a
new terminal widget for refinement logs. Esc closes the input widget without starting a
run.

## Implementation Flow

Implementation runs are gated on a valid issue number and a successful plan. When the
implementation completes, the UI appends a View PR button if the exit code is zero, or a
Re-implement button if the exit code is non-zero.

## Backward Compatibility

Session persistence uses schema versioning. Stored sessions are migrated on load so older
log arrays are converted into terminal widgets without data loss.
