"""
Claude Code token usage statistics module.

Parses JSONL files from ~/.claude/projects/**/*.jsonl to extract and aggregate
token usage statistics by time bucket.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path


def count_usage(mode: str, home_dir: str = None) -> dict:
    """
    Count token usage from Claude Code session files.

    Args:
        mode: "today" (hourly buckets) or "week" (daily buckets)
        home_dir: Override home directory (for testing)

    Returns:
        dict mapping bucket keys to stats:
        {
            "00:00": {"sessions": set(), "input": 0, "output": 0},
            "01:00": {"sessions": set(), "input": 0, "output": 0},
            ...
        }
    """
    home = Path(home_dir) if home_dir else Path.home()
    projects_dir = home / ".claude" / "projects"

    # Initialize buckets based on mode
    now = datetime.now()
    if mode == "week":
        # Daily buckets for last 7 days
        buckets = {}
        for i in range(7):
            day = now - timedelta(days=6 - i)
            key = day.strftime("%Y-%m-%d")
            buckets[key] = {"sessions": set(), "input": 0, "output": 0}
        cutoff = now - timedelta(days=7)
    else:
        # Hourly buckets for today (24 hours)
        buckets = {}
        for hour in range(24):
            key = f"{hour:02d}:00"
            buckets[key] = {"sessions": set(), "input": 0, "output": 0}
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
                            usage = entry.get("message", {}).get("usage", {})
                            input_tokens = usage.get("input_tokens", 0)
                            output_tokens = usage.get("output_tokens", 0)
                            if input_tokens > 0 or output_tokens > 0:
                                file_has_usage = True
                                buckets[bucket_key]["input"] += input_tokens
                                buckets[bucket_key]["output"] += output_tokens
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


def format_output(buckets: dict, mode: str) -> str:
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

    for key in sorted(buckets.keys()):
        stats = buckets[key]
        session_count = len(stats["sessions"])
        input_tokens = stats["input"]
        output_tokens = stats["output"]

        total_sessions.update(stats["sessions"])
        total_input += input_tokens
        total_output += output_tokens

        # Format: "HH:00   X sessions,   Y input,   Z output"
        session_word = "session" if session_count == 1 else "sessions"
        lines.append(
            f"{key}  {session_count:>3} {session_word:8}, "
            f"{format_number(input_tokens):>7} input, "
            f"{format_number(output_tokens):>7} output"
        )

    # Total line
    lines.append("")
    session_word = "session" if len(total_sessions) == 1 else "sessions"
    lines.append(
        f"Total: {len(total_sessions)} {session_word}, "
        f"{format_number(total_input)} input, "
        f"{format_number(total_output)} output"
    )

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

    args = parser.parse_args(argv)

    # Determine mode based on arguments
    mode = "week" if args.week else "today"

    # Get and display usage stats
    buckets = count_usage(mode)
    output = format_output(buckets, mode)
    print(output)


if __name__ == "__main__":
    main()
