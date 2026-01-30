# serve.sh

Polling server for automation workflows triggered by `lol serve`.

## External Interface

### lol serve

Starts a long-running worker that polls GitHub Projects for candidate issues and
spawns implementation worktrees.

**Configuration**:
- Uses `.agentize.local.yaml` for polling interval, concurrency, and Telegram
  notifications.
- CLI flags are not accepted; configuration is file-driven.

## Internal Helpers

### _lol_cmd_serve()
Private entrypoint that loads configuration, validates environment prerequisites,
and runs the polling loop.
