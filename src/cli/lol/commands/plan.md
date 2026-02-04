# plan.sh

Planning pipeline entrypoint for multi-agent debate workflows.

## External Interface

### lol plan

Runs the debate pipeline for a feature description or refines an existing plan
issue. The generated consensus plan ends with `Plan based on commit <hash>`.

**Usage**:
```bash
lol plan [--dry-run] [--verbose] [--editor] [--refine <issue-no> [refinement-instructions]] \
  [<feature-description>]
```

**Options**:
- `--dry-run`: Skip GitHub issue creation and use timestamp artifacts.
- `--verbose`: Print detailed stage logs.
- `--editor`: Open `$EDITOR` to compose the feature description; when combined with `--refine`, the editor text becomes the refinement focus.
- `--refine <issue-no>`: Refine an existing plan issue; refinement focus is composed from editor text when `--editor` is used. When both editor text and positional instructions are provided, the editor text appears first.

## Internal Helpers

### _lol_cmd_plan()
Private entrypoint that normalizes flags, loads planner modules, and executes the
pipeline with the selected mode.
