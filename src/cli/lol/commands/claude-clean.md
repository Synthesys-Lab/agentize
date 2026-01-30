# claude-clean.sh

Cleanup command for stale entries in `~/.claude.json`.

## External Interface

### lol claude-clean [--dry-run]

Scans Claude configuration for missing project paths and removes them (or prints
what would be removed in dry-run mode).

**Options**:
- `--dry-run`: Preview removals without modifying the file.

## Internal Helpers

### _lol_cmd_claude_clean()
Private entrypoint that validates dependencies, performs the scan, and writes
updated JSON atomically.
