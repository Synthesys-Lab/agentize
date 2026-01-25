# Handsoff Mode

Handsoff mode aims at minimizing user intervention during the development process.
By default, the agent will automatically proceed the task without asking user,
including the next steps and permissions.

To disable handsoff mode, set in `.agentize.local.yaml`:

```yaml
handsoff:
  enabled: false
  auto_permission: false
```

`handsoff.enabled` enables automatic continuation of the workflow.
Upon Claude `stop.py`, it feeds back a prompt to ask the agent
automatically determine the status of the current workflow.
If finished, stop the workflow. If not, continue to the next step.
Currently, we support:

- `ultra-planner` for planning tasks, until the detailed implementation plan is posted on Github Issues.
- `issue-to-impl` for implementation tasks, until the implementation is completed and PR is created.
  - Before creating PR, the agent will run tests, linters, and code reviews to ensure code quality.
- `plan-to-issue` for creating GitHub [plan] issues from user-provided plans until the issue is successfully created.

To differentiate each workflow, upon user prompt submit, we have a hook to create a metadata file
to store the workflow status metadata, including the current step, issue number, PR number, etc.
Currently, we register the hook for `ultra-planner`, `issue-to-impl`, and `plan-to-issue` workflows.

## Handsoff Mode Check

Hooks that need to respect handsoff mode use a centralized helper:

```python
from lib.session_utils import is_handsoff_enabled

if not is_handsoff_enabled():
    sys.exit(0)  # Skip hook when handsoff disabled
```

The helper reads `handsoff.enabled` from `.agentize.local.yaml` (searching project root → `$AGENTIZE_HOME` → `$HOME`). Returns `True` by default when not configured.
