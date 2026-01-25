# Troubleshoot

## Agentize failed to handsoff Claude Code session

Agentize is supposed to automatically execute all the `agentize:workflow`s,
including `/ultra-planner`, `/issue-to-impl`, `/sync-master`, etc.
However, if it sometimes fails to do so, including asking for permission
or not continuing the session automatically, you can enable debug logs
to help diagnose the issue.

Set `handsoff.debug: true` in `.agentize.local.yaml`:

```yaml
handsoff:
  debug: true
```

Then re-run the command to replicate the error. This will give you a detailed log in either
- `/path/to/your/project/.tmp/handsoff-debug.log` or
- `$HOME/.agentize/.tmp/handsoff-debug.log`

If you CANNOT fix the bug without modifying Agentize code, please paste your logs on issue for me (@were) to debug!

This depends on whether you both installed Agentize on Claude Code Plugin Marketplace
and our `install` script for CLI helpers.