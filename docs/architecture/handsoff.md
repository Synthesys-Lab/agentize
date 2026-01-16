# Handsoff Mode

Handsoff mode aims at minimizing user intervention during the development process.
In this mode, the agent will do its best to automatically proceed the task without
asking user, including the next steps and permissions.

```bash
export HANDSOFF_MODE=1
export HANDSOFF_AUTO_PERMISSION=1
```

where `HANDSOFF_MODE` enables automatic continuation of the workflow.
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
