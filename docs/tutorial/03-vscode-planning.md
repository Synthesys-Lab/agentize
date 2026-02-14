# Tutorial 03: VS Code Planning

**Read time: 4 minutes**

Use the VS Code Plan Activity Bar view to create a plan and launch implementation with a
single click.

## What You Will Do

- Load the Agentize Plan extension in VS Code
- Run a plan in the Plan Activity Bar panel
- Launch implementation from the Implement button
- Review plan and implementation logs separately

## Step 1: Load the Extension

From the repository root, install dependencies and compile the extension:

```bash
npm --prefix vscode install
npm --prefix vscode run compile
```

Then open the extension in VS Code:

```bash
code --extensionDevelopmentPath ./vscode
```

## Step 2: Open a Workspace

Open a workspace that contains an Agentize worktree. The extension looks for
`trees/main` first and falls back to the workspace root when it already contains the
Agentize CLI.

## Step 3: Run a Plan

1. Open the Plan view in the Activity Bar.
2. Click **New Plan**.
3. Enter a short prompt and click **Run Plan**.

The plan output streams into the Raw Console Log panel. When the planner creates a
placeholder issue, the extension captures the issue number from the output.

## Step 4: Implement the Plan

After the plan finishes successfully, the session header shows an **Implement** button.
Click it to run `lol impl <issue-number>`.

The implementation output appears in a separate **Implementation Log** panel, and the
button is disabled while the implementation run is active.

## Next Steps

- [Tutorial 02: Issue to Implementation](./02-issue-to-impl.md) for the CLI flow
- [Tutorial 03: Advanced Usage](./03-advanced-usage.md) for parallel workflows
