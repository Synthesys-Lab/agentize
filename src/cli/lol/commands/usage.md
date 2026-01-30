# usage.sh

Usage reporting for Claude Code token statistics.

## External Interface

### lol usage [--today | --week] [--cache] [--cost]

Aggregates token usage from `~/.claude/projects/**/*.jsonl` and prints formatted
buckets by hour or day.

**Options**:
- `--today`: Hourly buckets for the last 24 hours (default).
- `--week`: Daily buckets for the last 7 days.
- `--cache`: Include cache read/write token columns.
- `--cost`: Include estimated USD cost column.

## Internal Helpers

### _lol_cmd_usage()
Private entrypoint that delegates parsing and formatting to the usage utilities.
