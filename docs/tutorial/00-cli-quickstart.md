# Tutorial 00: CLI Quickstart

**Read time: 5 minutes**

Learn the core Agentize CLI workflow in about 15 minutes: configure -> clone -> plan -> implement -> navigate.

## What You Will Do

- Confirm your local Agentize configuration exists
- Clone a repository with the bare + worktree layout
- Create a plan with `lol plan --editor`
- Implement the plan with `lol impl <issue-number>`
- Move between worktrees with `wt goto`

## Step 1: Confirm Local Configuration

The installer creates `~/.agentize.local.yaml` in your home folder. This file controls which AI backends the planner and implementation workflow use.

Check that it exists:

```bash
ls ~/.agentize.local.yaml
```

If you want to change models or backends, open the file and edit the planner/impl settings. See `docs/cli/lol.md` for the full schema.

## Step 2: Clone With Worktrees

Agentize uses bare repositories with worktrees so each issue can live in its own working directory without branch conflicts.

Clone your project as a bare repo and initialize worktrees:

```bash
wt clone https://github.com/org/repo.git myproject.git
```

`wt clone` sets up the bare repository and puts you in `trees/main`, so you are ready to plan immediately.
See `docs/feat/cli/wt.md` for the full `wt` command reference.

## Step 3: Plan Your First Feature

Use the planner to create a GitHub issue with a consensus implementation plan:

```bash
lol plan --editor
```

If you do not have `$EDITOR` configured, pass the description directly:

```bash
lol plan "Add user authentication"
```

Review the newly created issue and make sure the plan matches what you want to build.
See `docs/cli/lol.md` for the full `lol` command reference.

## Step 4: Implement the Plan

Start the automated implementation loop for the issue:

```bash
lol impl <issue-number>
```

`lol impl` will create the issue worktree (if needed), enter it, and run the implementation workflow.

## Step 5: Navigate Between Worktrees

Jump between worktrees as you iterate:

```bash
wt goto <issue-number>
wt goto main
```

Use `wt list` to see all available worktrees at any time.

## Next Steps

- [Tutorial 01: Ultra Planner](./01-ultra-planner.md) for a deep dive on planning
- [Tutorial 02: Issue to Implementation](./02-issue-to-impl.md) for the full CLI loop
- [Tutorial 03: Advanced Usage](./03-advanced-usage.md) for parallel workflows and scaling up
