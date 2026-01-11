#!/usr/bin/env python3
"""
Python CLI entrypoint for lol commands.

Delegates to shell functions via bash -c with AGENTIZE_HOME set.
Provides argparse-style parsing while preserving shell as the canonical implementation.

Usage:
    python -m agentize.cli <command> [options]
"""

import argparse
import os
import sys

from agentize.shell import get_agentize_home, run_shell_function
from agentize.usage import count_usage, format_output


def run_shell_command(cmd: str, agentize_home: str) -> int:
    """Run a shell command with AGENTIZE_HOME set."""
    result = run_shell_function(cmd, agentize_home=agentize_home)
    return result.returncode


def handle_complete(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle --complete flag."""
    return run_shell_command(f'lol_complete "{args.complete}"', agentize_home)


def handle_version(agentize_home: str) -> int:
    """Handle --version flag."""
    return run_shell_command("lol_cmd_version", agentize_home)


def handle_init(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle init command."""
    path = args.path or os.getcwd()
    source = args.source or "src"
    metadata_only = "1" if args.metadata_only else "0"

    cmd = f'lol_cmd_init "{path}" "{args.name}" "{args.lang}" "{source}" "{metadata_only}"'
    return run_shell_command(cmd, agentize_home)


def handle_update(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle update command."""
    path = args.path or os.getcwd()
    cmd = f'lol_cmd_update "{path}"'
    return run_shell_command(cmd, agentize_home)


def handle_upgrade(agentize_home: str) -> int:
    """Handle upgrade command."""
    return run_shell_command("lol_cmd_upgrade", agentize_home)


def handle_project(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle project command."""
    if args.create:
        org = args.org or ""
        title = args.title or ""
        cmd = f'lol_cmd_project "create" "{org}" "{title}"'
    elif args.associate:
        cmd = f'lol_cmd_project "associate" "{args.associate}"'
    elif args.automation:
        write_path = args.write or ""
        cmd = f'lol_cmd_project "automation" "{write_path}"'
    else:
        print("Error: Must specify --create, --associate, or --automation")
        return 1
    return run_shell_command(cmd, agentize_home)


def handle_serve(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle serve command."""
    period = args.period or "5m"
    cmd = f'lol_cmd_serve "{period}" "{args.tg_token}" "{args.tg_chat_id}"'
    return run_shell_command(cmd, agentize_home)


def handle_claude_clean(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle claude-clean command."""
    dry_run = "1" if args.dry_run else "0"
    cmd = f'lol_cmd_claude_clean "{dry_run}"'
    return run_shell_command(cmd, agentize_home)


def handle_apply(args: argparse.Namespace, agentize_home: str) -> int:
    """Handle apply command."""
    if args.init:
        return handle_init(args, agentize_home)
    elif args.update:
        return handle_update(args, agentize_home)
    else:
        print("Error: Must specify --init or --update")
        return 1


def handle_usage(args: argparse.Namespace) -> int:
    """Handle usage command."""
    mode = "week" if args.week else "today"
    include_cache = getattr(args, "cache", False)
    include_cost = getattr(args, "cost", False)
    buckets = count_usage(mode, include_cache=include_cache, include_cost=include_cost)
    output = format_output(buckets, mode, show_cache=include_cache, show_cost=include_cost)
    print(output)
    return 0


def main() -> int:
    """Main entry point."""
    try:
        agentize_home = get_agentize_home()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 1

    parser = argparse.ArgumentParser(
        prog="python -m agentize.cli",
        description="AI-powered SDK CLI (Python wrapper)",
    )

    # Top-level flags
    parser.add_argument(
        "--complete",
        metavar="TOPIC",
        help="Shell-agnostic completion helper",
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Display version information",
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # apply command (the only way to init or update)
    apply_parser = subparsers.add_parser(
        "apply", help="Initialize or update SDK project (use --init or --update)"
    )
    apply_group = apply_parser.add_mutually_exclusive_group(required=True)
    apply_group.add_argument("--init", action="store_true", help="Use init mode")
    apply_group.add_argument("--update", action="store_true", help="Use update mode")
    apply_parser.add_argument("--name", help="Project name (required for --init)")
    apply_parser.add_argument("--lang", help="Programming language: c, cxx, python")
    apply_parser.add_argument("--path", help="Project path")
    apply_parser.add_argument("--source", help="Source code path relative to project root")
    apply_parser.add_argument(
        "--metadata-only", action="store_true", help="Create only metadata (--init only)"
    )

    # upgrade command
    subparsers.add_parser("upgrade", help="Upgrade agentize installation")

    # project command
    project_parser = subparsers.add_parser("project", help="GitHub Projects v2 integration")
    project_group = project_parser.add_mutually_exclusive_group(required=True)
    project_group.add_argument("--create", action="store_true", help="Create new project board")
    project_group.add_argument("--associate", metavar="ORG/ID", help="Associate existing project")
    project_group.add_argument("--automation", action="store_true", help="Generate automation workflow")
    project_parser.add_argument("--org", help="GitHub organization (for --create)")
    project_parser.add_argument("--title", help="Project title (for --create)")
    project_parser.add_argument("--write", help="Write automation to file (for --automation)")

    # serve command
    serve_parser = subparsers.add_parser("serve", help="GitHub Projects polling server")
    serve_parser.add_argument("--tg-token", required=True, help="Telegram bot token")
    serve_parser.add_argument("--tg-chat-id", required=True, help="Telegram chat ID")
    serve_parser.add_argument("--period", default="5m", help="Polling interval (default: 5m)")

    # usage command
    usage_parser = subparsers.add_parser(
        "usage", help="Report Claude Code token usage statistics"
    )
    usage_group = usage_parser.add_mutually_exclusive_group()
    usage_group.add_argument(
        "--today", action="store_true", default=True, help="Show usage by hour (default)"
    )
    usage_group.add_argument(
        "--week", action="store_true", help="Show usage by day for last 7 days"
    )
    usage_parser.add_argument(
        "--cache", action="store_true", help="Show cache read/write token columns"
    )
    usage_parser.add_argument(
        "--cost", action="store_true", help="Show estimated USD cost column"
    )

    # claude-clean command
    claude_clean_parser = subparsers.add_parser(
        "claude-clean", help="Remove stale project entries from ~/.claude.json"
    )
    claude_clean_parser.add_argument(
        "--dry-run", action="store_true", help="Preview changes without modifying"
    )

    # version command
    subparsers.add_parser("version", help="Display version information")

    args = parser.parse_args()

    # Handle top-level flags
    if args.complete:
        return handle_complete(args, agentize_home)

    if args.version:
        return handle_version(agentize_home)

    # Handle commands
    if args.command == "apply":
        return handle_apply(args, agentize_home)
    elif args.command == "upgrade":
        return handle_upgrade(agentize_home)
    elif args.command == "project":
        return handle_project(args, agentize_home)
    elif args.command == "serve":
        return handle_serve(args, agentize_home)
    elif args.command == "usage":
        return handle_usage(args)
    elif args.command == "claude-clean":
        return handle_claude_clean(args, agentize_home)
    elif args.command == "version":
        return handle_version(agentize_home)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
