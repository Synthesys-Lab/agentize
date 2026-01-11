"""
Claude Code token usage statistics module.

Parses JSONL files from ~/.claude/projects/**/*.jsonl to extract and aggregate
token usage statistics by time bucket.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path


# Static per-model pricing rates (USD per million tokens)
# Pricing last updated: 2026-01
MODEL_PRICING = {
    "claude-opus-4": {"input": 15.0, "output": 75.0, "cache_read": 1.875, "cache_write": 18.75},
    "claude-sonnet-4": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-3-7-sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-3-5-sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-3-5-haiku": {"input": 0.80, "output": 4.0, "cache_read": 0.08, "cache_write": 1.0},
    "claude-3-opus": {"input": 15.0, "output": 75.0, "cache_read": 1.875, "cache_write": 18.75},
    "claude-3-sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-3-haiku": {"input": 0.25, "output": 1.25, "cache_read": 0.03, "cache_write": 0.30},
}


def get_model_pricing() -> dict:
    """Returns static per-model pricing rates (USD per million tokens)."""
    return MODEL_PRICING.copy()


def match_model_pricing(model_id: str) -> dict | None:
    """Match a model ID to its pricing rates."""
    if not model_id:
        return None
    # Try prefix matching (e.g., "claude-3-5-sonnet-20241022" -> "claude-3-5-sonnet")
    for prefix, rates in MODEL_PRICING.items():
        if model_id.startswith(prefix):
            return rates
    return None


def format_cost(cost: float) -> str:
    """Format USD cost with dollar sign and appropriate precision."""
    return f"${cost:.2f}"


def count_usage(mode: str, home_dir: str = None, include_cache: bool = False, include_cost: bool = False) -> dict:
    """
    Count token usage from Claude Code session files.

    Args:
        mode: "today" (hourly buckets) or "week" (daily buckets)
        home_dir: Override home directory (for testing)
        include_cache: Include cache read/write token counts
        include_cost: Include estimated USD cost

    Returns:
        dict mapping bucket keys to stats:
        {
            "00:00": {"sessions": set(), "input": 0, "output": 0},
            "01:00": {"sessions": set(), "input": 0, "output": 0},
            ...
        }
        With include_cache=True, adds: "cache_read", "cache_write"
        With include_cost=True, adds: "cost_usd", "unknown_models"
    """
    home = Path(home_dir) if home_dir else Path.home()
    projects_dir = home / ".claude" / "projects"

    def make_bucket():
        """Create a new bucket with appropriate fields."""
        bucket = {"sessions": set(), "input": 0, "output": 0}
        if include_cache:
            bucket["cache_read"] = 0
            bucket["cache_write"] = 0
        if include_cost:
            bucket["cost_usd"] = 0.0
            bucket["unknown_models"] = set()
        return bucket

    # Initialize buckets based on mode
    now = datetime.now()
    if mode == "week":
        # Daily buckets for last 7 days
        buckets = {}
        for i in range(7):
            day = now - timedelta(days=6 - i)
            key = day.strftime("%Y-%m-%d")
            buckets[key] = make_bucket()
        cutoff = now - timedelta(days=7)
    else:
        # Hourly buckets for today (24 hours)
        buckets = {}
        for hour in range(24):
            key = f"{hour:02d}:00"
            buckets[key] = make_bucket()
        cutoff = now - timedelta(hours=24)

    # Return empty buckets if projects directory doesn't exist
    if not projects_dir.exists():
        return buckets

    # Find all JSONL files
    for jsonl_path in projects_dir.glob("**/*.jsonl"):
        try:
            # Filter by modification time
            mtime = datetime.fromtimestamp(jsonl_path.stat().st_mtime)
            if mtime < cutoff:
                continue

            # Determine bucket key for this file
            if mode == "week":
                bucket_key = mtime.strftime("%Y-%m-%d")
            else:
                bucket_key = f"{mtime.hour:02d}:00"

            if bucket_key not in buckets:
                continue

            # Parse JSONL file line by line for memory efficiency
            file_has_usage = False
            with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        # Extract usage from assistant messages
                        if entry.get("type") == "assistant":
                            message = entry.get("message", {})
                            usage = message.get("usage", {})
                            input_tokens = usage.get("input_tokens", 0)
                            output_tokens = usage.get("output_tokens", 0)
                            if input_tokens > 0 or output_tokens > 0:
                                file_has_usage = True
                                buckets[bucket_key]["input"] += input_tokens
                                buckets[bucket_key]["output"] += output_tokens

                                # Extract cache tokens if requested
                                if include_cache:
                                    cache_read = usage.get("cache_read_input_tokens", 0)
                                    cache_write = usage.get("cache_creation_input_tokens", 0)
                                    buckets[bucket_key]["cache_read"] += cache_read
                                    buckets[bucket_key]["cache_write"] += cache_write

                                # Compute cost if requested
                                if include_cost:
                                    model_id = message.get("model", "")
                                    rates = match_model_pricing(model_id)
                                    if rates:
                                        # Compute cost per million tokens
                                        cache_read = usage.get("cache_read_input_tokens", 0)
                                        cache_write = usage.get("cache_creation_input_tokens", 0)
                                        # Non-cache input = total input - cache_read - cache_write
                                        non_cache_input = max(0, input_tokens - cache_read - cache_write)
                                        cost = (
                                            non_cache_input * rates["input"] / 1_000_000
                                            + output_tokens * rates["output"] / 1_000_000
                                            + cache_read * rates["cache_read"] / 1_000_000
                                            + cache_write * rates["cache_write"] / 1_000_000
                                        )
                                        buckets[bucket_key]["cost_usd"] += cost
                                    elif model_id:
                                        buckets[bucket_key]["unknown_models"].add(model_id)
                    except (json.JSONDecodeError, KeyError):
                        # Skip malformed lines
                        continue

            # Count session if file had any usage data
            if file_has_usage:
                buckets[bucket_key]["sessions"].add(str(jsonl_path))

        except (OSError, IOError):
            # Skip files we can't read
            continue

    return buckets


def format_number(n: int) -> str:
    """Format number with K/M suffix for readability."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.1f}K"
    else:
        return str(n)


def format_output(buckets: dict, mode: str, show_cache: bool = False, show_cost: bool = False) -> str:
    """Format bucket stats as human-readable table."""
    lines = []

    # Header
    now = datetime.now()
    if mode == "week":
        lines.append(f"Weekly Usage ({now.strftime('%Y-%m-%d')}):")
    else:
        lines.append(f"Today's Usage ({now.strftime('%Y-%m-%d')}):")

    # Data rows
    total_sessions = set()
    total_input = 0
    total_output = 0
    total_cache_read = 0
    total_cache_write = 0
    total_cost = 0.0
    all_unknown_models = set()

    for key in sorted(buckets.keys()):
        stats = buckets[key]
        session_count = len(stats["sessions"])
        input_tokens = stats["input"]
        output_tokens = stats["output"]

        total_sessions.update(stats["sessions"])
        total_input += input_tokens
        total_output += output_tokens

        # Build row
        session_word = "session" if session_count == 1 else "sessions"
        row = (
            f"{key}  {session_count:>3} {session_word:8}, "
            f"{format_number(input_tokens):>7} input, "
            f"{format_number(output_tokens):>7} output"
        )

        if show_cache:
            cache_read = stats.get("cache_read", 0)
            cache_write = stats.get("cache_write", 0)
            total_cache_read += cache_read
            total_cache_write += cache_write
            row += f", {format_number(cache_read):>7} cache_read, {format_number(cache_write):>7} cache_write"

        if show_cost:
            cost = stats.get("cost_usd", 0.0)
            total_cost += cost
            row += f", {format_cost(cost):>8}"
            unknown = stats.get("unknown_models", set())
            all_unknown_models.update(unknown)

        lines.append(row)

    # Total line
    lines.append("")
    session_word = "session" if len(total_sessions) == 1 else "sessions"
    total_row = (
        f"Total: {len(total_sessions)} {session_word}, "
        f"{format_number(total_input)} input, "
        f"{format_number(total_output)} output"
    )

    if show_cache:
        total_row += f", {format_number(total_cache_read)} cache_read, {format_number(total_cache_write)} cache_write"

    if show_cost:
        total_row += f", {format_cost(total_cost)}"

    lines.append(total_row)

    # Warning for cost estimates
    if show_cost:
        lines.append("")
        lines.append("Warning: Cost is an estimate based on static per-model rates. Actual billing may vary.")
        if all_unknown_models:
            lines.append(f"Unknown models (cost not computed): {', '.join(sorted(all_unknown_models))}")

    return "\n".join(lines)


def main(argv=None):
    """
    CLI entrypoint for usage statistics.

    Args:
        argv: Command-line arguments (defaults to sys.argv[1:])
    """
    import argparse
    import sys

    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(
        prog="usage",
        description="Report Claude Code token usage statistics"
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--today",
        action="store_true",
        default=True,
        help="Show usage by hour for the last 24 hours (default)"
    )
    group.add_argument(
        "--week",
        action="store_true",
        help="Show usage by day for the last 7 days"
    )
    parser.add_argument(
        "--cache",
        action="store_true",
        help="Show cache read/write token columns"
    )
    parser.add_argument(
        "--cost",
        action="store_true",
        help="Show estimated USD cost column"
    )

    args = parser.parse_args(argv)

    # Determine mode based on arguments
    mode = "week" if args.week else "today"

    # Get and display usage stats
    buckets = count_usage(mode, include_cache=args.cache, include_cost=args.cost)
    output = format_output(buckets, mode, show_cache=args.cache, show_cost=args.cost)
    print(output)


if __name__ == "__main__":
    main()
