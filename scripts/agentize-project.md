# agentize-project.sh

Compatibility wrapper for running project automation via environment variables.

## External Interface

### ./scripts/agentize-project.sh

Reads environment variables to select the project mode and arguments, then
delegates to the `lol` implementation.

**Environment variables**:
- `AGENTIZE_PROJECT_MODE`: `create`, `associate`, or `automation`.
- `AGENTIZE_PROJECT_ORG`: Org for create mode.
- `AGENTIZE_PROJECT_TITLE`: Title for create mode.
- `AGENTIZE_PROJECT_ASSOCIATE`: Org/ID for associate mode.
- `AGENTIZE_PROJECT_WRITE_PATH`: Output path for automation mode.

## Internal Helpers

Delegates to `_lol_cmd_project()` after sourcing `src/cli/lol.sh`.
