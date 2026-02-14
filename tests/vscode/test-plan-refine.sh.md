# test-plan-refine.sh

Validates refinement wiring for the VS Code plan view.

## Test Cases

### RunPlanInput includes refineIssueNumber
**Purpose**: Ensure the runner input type exposes an optional refine issue number.
**Expected**: `vscode/src/runner/types.ts` contains `refineIssueNumber`.

### buildCommand refine branch exists
**Purpose**: Ensure the runner builds `lol plan --refine <issue> "<prompt>"` when refining.
**Expected**: `vscode/src/runner/planRunner.ts` contains the `--refine` flag and uses `refineIssueNumber`.

### buildCommand default branch exists
**Purpose**: Ensure non-refine runs still push the prompt without refine flags.
**Expected**: `vscode/src/runner/planRunner.ts` retains the default `args.push(input.prompt)` path.

### PlanViewProvider handles plan/refine
**Purpose**: Ensure the extension host accepts `plan/refine` messages.
**Expected**: `vscode/src/view/planViewProvider.ts` contains a `plan/refine` handler.

### Webview triggers refinement
**Purpose**: Ensure the webview posts the refine message and styles the button.
**Expected**: `vscode/webview/plan/index.ts` posts `plan/refine`, and `styles.css` defines `.refine`.
