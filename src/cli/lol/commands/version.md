# version.sh

Implements version reporting for the `lol` CLI.

## External Interface

### lol --version / lol version

Prints installation and project version information derived from git commits.

**Output**:
- Installation commit hash from `AGENTIZE_HOME`.
- Last update commit hash from `.agentize.yaml` when available.

## Internal Helpers

### _lol_cmd_version()
Private entrypoint that validates arguments and prints formatted version output.
