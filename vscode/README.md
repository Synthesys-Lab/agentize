# VS Code Agentize Extension

This directory contains a VS Code Activity Bar extension that wraps the Agentize CLI
planning workflow and surfaces it in a webview.

## Organization

- `src/` contains extension backend code (state, runner, and view wiring).
- `webview/` contains the Plan tab UI assets rendered in the Activity Bar webview.
- `bin/` contains helper executables used by the extension runtime.

## Plan to Implementation Flow

When a plan finishes successfully and the planner creates a placeholder GitHub issue, the
Plan tab surfaces an Implement button. Clicking it launches `lol impl <issue-number>` in a
separate Implementation Log panel so plan and implementation output stay distinct.

## Prerequisites

- Node.js + npm (for compiling the extension TypeScript).
- Bash (used by the `lol` wrapper).
- A generated `setup.sh` in the repository root (run `make setup` from the repo
  root that contains `vscode/`).

## Build

```bash
npm --prefix vscode install
npm --prefix vscode run compile
```

For development watch mode:

```bash
npm --prefix vscode run watch
```

## Load in VS Code

- Command line: `code --extensionDevelopmentPath ./vscode`
- Or use the VS Code command palette: "Developer: Install Extension from
  Location..." and choose the `vscode/` folder.

## Workspace Requirement

The Plan runner needs a working directory where the Agentize CLI is available.
It resolves the planning working directory with the following rules:

- If any opened workspace folder contains `trees/main` (created by `wt init` or
  `wt clone`), the runner uses `<workspace>/trees/main`.
- Otherwise, it falls back to the workspace folder root (useful when you open a
  single worktree like `trees/issue-866` directly).

## Refining Plans

When a plan session completes (success or error), a Refine button appears on the
session card.

1. Click Refine on the completed session.
1. Enter the issue number to refine.
1. Enter the refinement focus or instructions.

The extension runs `lol plan --refine <issue> "<focus>"` and streams the
refinement session in the plan view like any other run.
