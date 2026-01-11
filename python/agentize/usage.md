# Usage Statistics Module Interface

Token usage statistics from Claude Code session files.

## External Interface

### count_usage

```python
def count_usage(mode: str, home_dir: str = None, include_cache: bool = False, include_cost: bool = False) -> dict
```

Count token usage from Claude Code session files.

**Parameters:**
- `mode` - Time bucket mode: `"today"` (hourly) or `"week"` (daily)
- `home_dir` - Override home directory (for testing, defaults to `Path.home()`)
- `include_cache` - Include cache read/write token counts
- `include_cost` - Include estimated USD cost

**Returns:**
Dict mapping bucket keys to stats:
```python
# Default (include_cache=False, include_cost=False):
{
    "00:00": {"sessions": set(), "input": 0, "output": 0},  # today mode
    "2026-01-10": {"sessions": set(), "input": 0, "output": 0},  # week mode
}

# With include_cache=True:
{
    "00:00": {"sessions": set(), "input": 0, "output": 0, "cache_read": 0, "cache_write": 0},
}

# With include_cost=True:
{
    "00:00": {"sessions": set(), "input": 0, "output": 0, "cost_usd": 0.0, "unknown_models": set()},
}

# With both include_cache=True and include_cost=True:
{
    "00:00": {"sessions": set(), "input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "cost_usd": 0.0, "unknown_models": set()},
}
```

**Behavior:**
- Scans `~/.claude/projects/**/*.jsonl` files
- Filters by modification time (24h for today, 7d for week)
- Extracts `input_tokens` and `output_tokens` from assistant messages
- Counts unique sessions (one JSONL file = one session)
- Returns empty buckets if `~/.claude/projects` doesn't exist
- Cache tokens: Extracts `cache_read_input_tokens` and `cache_creation_input_tokens` when `include_cache=True`
- Cost estimation: Computes per-message cost using `message.model` when `include_cost=True`

### format_output

```python
def format_output(buckets: dict, mode: str, show_cache: bool = False, show_cost: bool = False) -> str
```

Format bucket stats as human-readable table.

**Parameters:**
- `buckets` - Dict from `count_usage()`
- `mode` - `"today"` or `"week"` (affects header text)
- `show_cache` - Include cache read/write columns
- `show_cost` - Include USD cost column

**Returns:**
Formatted string with header, per-bucket rows, and total line.
When `show_cost=True`, appends warning about estimate accuracy.

### get_model_pricing

```python
def get_model_pricing() -> dict
```

Returns static per-model pricing rates (USD per million tokens).

**Returns:**
Dict mapping model ID patterns to pricing:
```python
{
    "claude-3-opus": {"input": 15.0, "output": 75.0, "cache_read": 1.875, "cache_write": 18.75},
    "claude-3-5-sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-3-5-haiku": {"input": 0.80, "output": 4.0, "cache_read": 0.08, "cache_write": 1.0},
    # ... additional models
}
```

**Pricing last updated:** 2026-01

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

### format_cost

```python
def format_cost(cost: float) -> str
```

Format USD cost with dollar sign and appropriate precision.

**Examples:**
- `0.001` → `"$0.00"`
- `0.125` → `"$0.12"`
- `12.50` → `"$12.50"`

### match_model_pricing

```python
def match_model_pricing(model_id: str) -> dict | None
```

Match a model ID to its pricing rates.

**Parameters:**
- `model_id` - Full model identifier (e.g., "claude-3-5-sonnet-20241022")

**Returns:**
Pricing dict if matched, None if unknown model.
