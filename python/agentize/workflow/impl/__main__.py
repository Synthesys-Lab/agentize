"""CLI entrypoint for the impl workflow."""

from __future__ import annotations

import argparse
import sys

from agentize.workflow.impl.impl import ImplError, run_impl_workflow


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Issue-to-implementation workflow (Python impl)",
    )
    parser.add_argument("issue_no", type=int, help="Issue number to implement")
    parser.add_argument(
        "--backend",
        default="codex:gpt-5.2-codex",
        help="Backend in provider:model format",
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=10,
        help="Maximum iteration count",
    )
    parser.add_argument(
        "--yolo",
        action="store_true",
        help="Pass through --yolo to acw",
    )
    args = parser.parse_args(argv)

    try:
        run_impl_workflow(
            args.issue_no,
            backend=args.backend,
            max_iterations=args.max_iterations,
            yolo=args.yolo,
        )
    except (ImplError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
