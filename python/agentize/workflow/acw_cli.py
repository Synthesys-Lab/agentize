"""CLI wrapper for running a single ACW execution."""

from __future__ import annotations

import argparse
import sys

from agentize.workflow.utils import ACW


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a single ACW execution")
    parser.add_argument("--name", required=True, help="Label for ACW logs")
    parser.add_argument("--provider", required=True, help="Provider name")
    parser.add_argument("--model", required=True, help="Model identifier")
    parser.add_argument("--input", required=True, help="Path to input prompt file")
    parser.add_argument("--output", required=True, help="Path to output file")
    parser.add_argument("--timeout", type=int, default=900, help="Timeout in seconds")
    parser.add_argument("--tools", default=None, help="Tool configuration (Claude only)")
    parser.add_argument(
        "--permission-mode",
        default=None,
        help="Permission mode override (Claude only)",
    )
    parser.add_argument(
        "--yolo",
        action="store_true",
        help="Pass --yolo through to provider CLI",
    )
    return parser.parse_args(argv)


def _build_acw(args: argparse.Namespace) -> ACW:
    extra_flags: list[str] = []
    if args.yolo:
        extra_flags.append("--yolo")

    return ACW(
        name=args.name,
        provider=args.provider,
        model=args.model,
        timeout=args.timeout,
        tools=args.tools,
        permission_mode=args.permission_mode,
        extra_flags=extra_flags or None,
    )


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv or sys.argv[1:])
    try:
        runner = _build_acw(args)
        result = runner.run(args.input, args.output)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
