# plan.sh

Planning pipeline entrypoint for multi-agent debate workflows.

## External Interface

### lol plan

Runs the debate pipeline for a feature description or refines an existing plan
issue.

**Usage**:
```bash
lol plan [--dry-run] [--verbose] [--editor] [--refine <issue-no> [refinement-instructions]] \
  [<feature-description>]
```

**Options**:
- `--dry-run`: Skip GitHub issue creation and use timestamp artifacts.
- `--verbose`: Print detailed stage logs.
- `--editor`: Open `$EDITOR` to compose the feature description.
- `--refine <issue-no>`: Refine an existing plan issue.

## Internal Helpers

### _lol_cmd_plan()
Private entrypoint that normalizes flags, loads planner modules, and executes the
pipeline with the selected mode.
