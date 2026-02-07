"""CLI entrypoint for the simp workflow."""

from __future__ import annotations

import argparse
import sys

from agentize.workflow.simp.simp import SimpError, run_simp_workflow


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Semantic-preserving simplifier workflow (Python simp)",
    )
    parser.add_argument("file", nargs="?", help="Optional file to simplify")
    parser.add_argument(
        "--backend",
        default="codex:gpt-5.2-codex",
        help="Backend in provider:model format",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=3,
        help="Maximum files to select when no file is provided",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Random seed for file selection",
    )
    parser.add_argument(
        "--focus",
        default=None,
        help="Optional focus description to guide simplification",
    )
    args = parser.parse_args(argv)

    try:
        run_simp_workflow(
            args.file,
            backend=args.backend,
            max_files=args.max_files,
            seed=args.seed,
            focus=args.focus,
        )
    except (SimpError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
