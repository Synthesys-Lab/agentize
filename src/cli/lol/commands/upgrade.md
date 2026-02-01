# upgrade.sh

Implements `lol upgrade` for refreshing the agentize installation.

## External Interface

### lol upgrade [--keep-branch]

Pulls the latest changes, rebuilds `setup.sh`, and refreshes optional tooling.

**Behavior**:
- Requires a clean git worktree.
- Switches to the default branch before pulling unless `--keep-branch` is used.
- With `--keep-branch`, pulls the current branch's upstream instead of switching.
- Runs `make setup` to regenerate environment scripts.
- Attempts to update the Claude plugin when available.

## Internal Helpers

### _lol_cmd_upgrade()
Private entrypoint that performs the upgrade workflow and prints shell reload
instructions on success.
