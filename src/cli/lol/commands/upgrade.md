# upgrade.sh

Implements `lol upgrade` for refreshing the agentize installation.

## External Interface

### lol upgrade

Pulls the latest changes, rebuilds `setup.sh`, and refreshes optional tooling.

**Behavior**:
- Requires a clean git worktree.
- Runs `git pull --rebase` against the default branch.
- Runs `make setup` to regenerate environment scripts.
- Attempts to update the Claude plugin when available.

## Internal Helpers

### _lol_cmd_upgrade()
Private entrypoint that performs the upgrade workflow and prints shell reload
instructions on success.
