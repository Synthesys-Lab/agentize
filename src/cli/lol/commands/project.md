# project.sh

GitHub Projects v2 integration for the `lol project` command.

## External Interface

### lol project

Supports create, associate, and automation modes:

```bash
lol project --create [--org <owner>] [--title <title>]
lol project --associate <owner>/<id>
lol project --automation [--write <path>]
```

**Behavior**:
- Uses `gh` for GraphQL requests.
- Stores project metadata in `.agentize.yaml`.
- Generates automation workflow output in automation mode.

## Internal Helpers

### _lol_cmd_project()
Private entrypoint that dispatches to project library helpers based on mode and
positional arguments.
