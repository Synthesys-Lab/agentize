"""CLI entrypoint for the impl workflow."""

from __future__ import annotations

import argparse
import sys
import warnings

from agentize.workflow.impl.impl import ImplError, run_impl_workflow


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Issue-to-implementation workflow (Python impl)",
    )
    parser.add_argument("issue_no", type=int, help="Issue number to implement")
    parser.add_argument(
        "--backend",
        default=None,
        help="Backend in provider:model format (deprecated, use --impl-model)",
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=None,
        help="Maximum iteration count (deprecated, use --max-iter)",
    )
    parser.add_argument(
        "--max-iter",
        type=int,
        default=10,
        help="Maximum implementation iterations (default: 10)",
    )
    parser.add_argument(
        "--max-reviews",
        type=int,
        default=8,
        help="Maximum review attempts per iteration (default: 8)",
    )
    parser.add_argument(
        "--impl-model",
        default=None,
        help="Model for implementation stage (format: provider:model)",
    )
    parser.add_argument(
        "--review-model",
        default=None,
        help="Model for review stage (format: provider:model, defaults to impl-model)",
    )
    parser.add_argument(
        "--yolo",
        action="store_true",
        help="Pass through --yolo to acw",
    )
    parser.add_argument(
        "--wait-for-ci",
        action="store_true",
        help="Monitor PR mergeability and CI after creation",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from checkpoint if available",
    )
    parser.add_argument(
        "--enable-review",
        action="store_true",
        help="Enable the review stage (experimental)",
    )
    parser.add_argument(
        "--enable-simp",
        action="store_true",
        help="Enable the simplification stage (experimental)",
    )
    args = parser.parse_args(argv)

    # Handle deprecated arguments
    max_iter = args.max_iter
    if args.max_iterations is not None:
        warnings.warn(
            "--max-iterations is deprecated, use --max-iter instead",
            DeprecationWarning,
        )
        max_iter = args.max_iterations

    backend = args.backend
    impl_model = args.impl_model
    if backend is not None:
        warnings.warn(
            "--backend is deprecated, use --impl-model instead",
            DeprecationWarning,
        )
        if impl_model is None:
            impl_model = backend

    try:
        run_impl_workflow(
            args.issue_no,
            backend=backend,
            max_iterations=max_iter,
            max_reviews=args.max_reviews,
            yolo=args.yolo,
            wait_for_ci=args.wait_for_ci,
            resume=args.resume,
            impl_model=impl_model,
            review_model=args.review_model,
            enable_review=args.enable_review,
            enable_simp=args.enable_simp,
        )
    except (ImplError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
