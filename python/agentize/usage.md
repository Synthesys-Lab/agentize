# Usage Statistics Module Interface

Token usage statistics from Claude Code session files.

## External Interface

### count_usage

```python
def count_usage(mode: str, home_dir: str = None) -> dict
```

Count token usage from Claude Code session files.

**Parameters:**
- `mode` - Time bucket mode: `"today"` (hourly) or `"week"` (daily)
- `home_dir` - Override home directory (for testing, defaults to `Path.home()`)

**Returns:**
Dict mapping bucket keys to stats:
```python
{
    "00:00": {"sessions": set(), "input": 0, "output": 0},  # today mode
    "2026-01-10": {"sessions": set(), "input": 0, "output": 0},  # week mode
}
```

**Behavior:**
- Scans `~/.claude/projects/**/*.jsonl` files
- Filters by modification time (24h for today, 7d for week)
- Extracts `input_tokens` and `output_tokens` from assistant messages
- Counts unique sessions (one JSONL file = one session)
- Returns empty buckets if `~/.claude/projects` doesn't exist

### format_output

```python
def format_output(buckets: dict, mode: str) -> str
```

Format bucket stats as human-readable table.

**Parameters:**
- `buckets` - Dict from `count_usage()`
- `mode` - `"today"` or `"week"` (affects header text)

**Returns:**
Formatted string with header, per-bucket rows, and total line.

## Internal Helpers

### format_number

```python
def format_number(n: int) -> str
```

Format number with K/M suffix for readability.

**Examples:**
- `999` → `"999"`
- `1500` → `"1.5K"`
- `1500000` → `"1.5M"`
