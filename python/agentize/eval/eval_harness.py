"""SWE-bench evaluation harness for agentize.

Single-file harness that loads SWE-bench tasks from HuggingFace, runs the
agentize impl pipeline against each task in an isolated git worktree, extracts
patches, and scores them via the SWE-bench Docker evaluator.

Supports two execution modes:
  - raw:  baseline Claude via ``claude -p`` (tests the model alone)
  - full: agentize planning pipeline + FSM orchestrator (tests the framework)

Usage:
    python -m agentize.eval.eval_harness run --mode raw --limit 1 --dry-run
    python -m agentize.eval.eval_harness run --mode full --limit 1
    python -m agentize.eval.eval_harness score --predictions .tmp/eval/predictions.jsonl
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


# ---------------------------------------------------------------------------
# Task loading
# ---------------------------------------------------------------------------

def load_tasks(
    dataset_name: str = "princeton-nlp/SWE-bench_Lite",
    instance_ids: list[str] | None = None,
    limit: int | None = None,
) -> list[dict]:
    """Load SWE-bench tasks from HuggingFace.

    Each task is a plain dict with keys: instance_id, repo, base_commit,
    problem_statement, patch (gold), test_patch, fail_to_pass, pass_to_pass,
    hints_text, version, etc.
    """
    from datasets import load_dataset

    ds = load_dataset(dataset_name, split="test")
    tasks = list(ds)

    if instance_ids:
        id_set = set(instance_ids)
        tasks = [t for t in tasks if t["instance_id"] in id_set]

    if limit:
        tasks = tasks[:limit]

    return tasks


# ---------------------------------------------------------------------------
# Repository and worktree setup
# ---------------------------------------------------------------------------

def setup_worktree(
    task: dict,
    repos_dir: str | Path,
    worktrees_dir: str | Path,
) -> str:
    """Clone repo (if needed) and create worktree at base_commit.

    Returns the worktree path.
    """
    repo = task["repo"]  # e.g. "django/django"
    instance_id = task["instance_id"]
    base_commit = task["base_commit"]

    repos_dir = Path(repos_dir).resolve()
    worktrees_dir = Path(worktrees_dir).resolve()

    # Clone bare repo (cache across tasks from same repo)
    bare_path = repos_dir / (repo.replace("/", "__") + ".git")
    if not bare_path.exists():
        bare_path.parent.mkdir(parents=True, exist_ok=True)
        _run(["git", "clone", "--bare",
              f"https://github.com/{repo}.git", str(bare_path)])

    # Create worktree at base_commit (skip if exists for resume support)
    wt_path = worktrees_dir / instance_id
    if wt_path.exists():
        return str(wt_path)

    wt_path.parent.mkdir(parents=True, exist_ok=True)
    # Prune stale worktree registrations before creating
    _run(["git", "-C", str(bare_path), "worktree", "prune"], check=False)
    _run(["git", "-C", str(bare_path), "worktree", "add",
          "--detach", str(wt_path), base_commit])

    # Write problem statement as synthetic issue file
    issue_path = wt_path / ".issue.md"
    issue_path.write_text(task["problem_statement"], encoding="utf-8")

    return str(wt_path)


def cleanup_worktree(
    wt_path: str | Path,
    repos_dir: str | Path,
    repo: str,
) -> None:
    """Remove a worktree from the bare repo."""
    bare_path = Path(repos_dir) / (repo.replace("/", "__") + ".git")
    _run(["git", "-C", str(bare_path), "worktree", "remove",
          "--force", str(wt_path)], check=False)


# ---------------------------------------------------------------------------
# Shell overrides for offline execution
# ---------------------------------------------------------------------------

def write_overrides(wt_path: str | Path, instance_id: str) -> str:
    """Write AGENTIZE_SHELL_OVERRIDES script for offline execution.

    Stubs gh, wt, and git push so the impl pipeline runs without
    network access to GitHub.

    Returns the overrides file path.
    """
    overrides_path = Path(wt_path) / ".eval-overrides.sh"
    overrides_path.write_text(
        f"""\
#!/usr/bin/env bash
# Eval overrides for {instance_id}
# Stub gh CLI (no GitHub access during eval)
gh() {{ echo "STUB: gh $*" >&2; }}
# Stub wt (pathto returns ".", everything else is a no-op)
wt() {{
  case "$1" in
    pathto) echo "." ;;
    *) echo "STUB: wt $*" >&2 ;;
  esac
}}
# Prevent git push/fetch/rebase (allow other git commands)
git() {{
  case "$1" in
    push|fetch|rebase) echo "STUB: git $1 blocked" >&2; return 0 ;;
    *) command git "$@" ;;
  esac
}}
export -f gh wt git
""",
        encoding="utf-8",
    )
    return str(overrides_path)


# ---------------------------------------------------------------------------
# Implementation execution
# ---------------------------------------------------------------------------

def run_impl(
    wt_path: str | Path,
    overrides_path: str,
    instance_id: str,
    timeout: int = 1800,
    model: str = "sonnet",
) -> dict:
    """Run claude against the task and return a result dict.

    Uses ``claude -p`` in headless mode with JSON output for token tracking.
    """
    env = os.environ.copy()
    env["AGENTIZE_SHELL_OVERRIDES"] = overrides_path

    start_time = time.time()
    result = {
        "instance_id": instance_id,
        "status": "error",
        "wall_time": 0.0,
        "tokens": 0,
    }

    prompt = (
        "Read .issue.md and implement the fix described. "
        "Make minimal changes to resolve the issue. "
        "Do not create tests. Do not modify documentation."
    )

    try:
        proc = subprocess.run(
            ["claude", "-p", "--output-format", "json",
             "--model", model, prompt],
            cwd=str(wt_path),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        result["wall_time"] = time.time() - start_time

        # Parse Claude JSON output for token usage
        if proc.stdout:
            try:
                claude_output = json.loads(proc.stdout)
                usage = claude_output.get("usage", {})
                result["tokens"] = (
                    usage.get("input_tokens", 0)
                    + usage.get("output_tokens", 0)
                )
            except json.JSONDecodeError:
                pass

        result["status"] = "completed" if proc.returncode == 0 else "failed"
    except subprocess.TimeoutExpired:
        result["status"] = "timeout"
        result["wall_time"] = float(timeout)

    return result


# ---------------------------------------------------------------------------
# Full-mode: kernel substitution stubs
# ---------------------------------------------------------------------------

def _eval_pr_kernel(context):
    """No-op PR kernel for eval mode — skips GitHub PR creation."""
    from agentize.workflow.impl.state import EVENT_PR_PASS, StageResult

    return StageResult(event=EVENT_PR_PASS, reason="eval mode: PR skipped")


def _eval_rebase_kernel(context):
    """No-op rebase kernel for eval mode — skips git rebase."""
    from agentize.workflow.impl.state import EVENT_REBASE_OK, StageResult

    return StageResult(event=EVENT_REBASE_OK, reason="eval mode: rebase skipped")


def _build_eval_kernels():
    """Build kernel registry with PR/rebase replaced by no-ops."""
    from agentize.workflow.impl.kernels import KERNELS
    from agentize.workflow.impl.state import STAGE_PR, STAGE_REBASE

    eval_kernels = dict(KERNELS)
    eval_kernels[STAGE_PR] = _eval_pr_kernel
    eval_kernels[STAGE_REBASE] = _eval_rebase_kernel
    return eval_kernels


# ---------------------------------------------------------------------------
# Full-mode: planning phase
# ---------------------------------------------------------------------------

def run_planning_phase(
    problem_statement: str,
    output_dir: Path,
    model: str = "sonnet",
) -> str:
    """Run the agentize planner pipeline and return formatted issue content.

    Calls ``run_planner_pipeline()`` with the SWE-bench problem statement,
    extracts the consensus plan, and formats it as an issue file that
    ``impl_stage_kernel`` can consume.
    """
    from agentize.workflow.planner.pipeline import run_planner_pipeline

    results = run_planner_pipeline(
        feature_desc=problem_statement,
        output_dir=str(output_dir),
    )

    consensus = results.get("consensus")
    plan_text = consensus.text() if consensus and consensus.output_path.exists() else ""

    return (
        f"# SWE-bench Task\n\n"
        f"## Problem Statement\n\n{problem_statement}\n\n"
        f"## Implementation Plan (Consensus)\n\n{plan_text}\n\n"
        f"## Instructions\n\nImplement the fix. Follow the plan. Make minimal changes.\n"
    )


# ---------------------------------------------------------------------------
# Full-mode: FSM orchestrator execution
# ---------------------------------------------------------------------------

def run_full_impl(
    wt_path: str | Path,
    overrides_path: str,
    instance_id: str,
    problem_statement: str,
    timeout: int = 1800,
    model: str = "sonnet",
    enable_review: bool = False,
    enable_simp: bool = False,
    max_iterations: int = 10,
) -> dict:
    """Run the full agentize pipeline (planning + FSM impl) against a task.

    Uses kernel substitution to skip PR/rebase stages while reusing the
    production transition table unchanged.
    """
    from agentize.workflow.api import Session
    from agentize.workflow.impl.checkpoint import create_initial_state
    from agentize.workflow.impl.orchestrator import run_fsm_orchestrator
    from agentize.workflow.impl.state import STAGE_FINISH, WorkflowContext

    wt = Path(wt_path)
    tmp_dir = wt / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["AGENTIZE_SHELL_OVERRIDES"] = overrides_path

    start_time = time.time()
    result = {
        "instance_id": instance_id,
        "status": "error",
        "wall_time": 0.0,
        "tokens": 0,
    }

    try:
        # Run planning phase and write issue file where impl_kernel expects it
        issue_content = run_planning_phase(problem_statement, tmp_dir, model)
        issue_file = tmp_dir / "issue-1.md"
        issue_file.write_text(issue_content, encoding="utf-8")

        # Build state and context
        state = create_initial_state(issue_no=1, worktree=wt)
        session = Session(output_dir=tmp_dir, prefix=f"eval-{instance_id}")

        # Resolve template path (same one used by production impl)
        from agentize.workflow.impl.impl import rel_path
        template_path = rel_path("continue-prompt.md")

        context = WorkflowContext(
            plan="",
            upstream_instruction="",
            current_stage="impl",
            data={
                "impl_state": state,
                "session": session,
                "template_path": template_path,
                "impl_provider": "claude",
                "impl_model": model,
                "review_provider": "claude",
                "review_model": model,
                "yolo": False,
                "enable_review": enable_review,
                "enable_simp": enable_simp,
                "max_iterations": max_iterations,
                "max_reviews": 8,
                "push_remote": None,
                "base_branch": None,
                "checkpoint_path": tmp_dir / "impl-checkpoint.json",
                "parse_fail_streak": 0,
                "review_fail_streak": 0,
                "last_review_score": None,
                "retry_context": None,
                "review_attempts": 0,
                "simp_attempts": 0,
                "max_simps": 3,
                "pr_attempts": 0,
                "rebase_attempts": 0,
            },
        )

        # Run FSM with eval kernels (PR/rebase are no-ops)
        eval_kernels = _build_eval_kernels()
        context = run_fsm_orchestrator(context, kernels=eval_kernels)

        result["status"] = "completed" if context.current_stage == STAGE_FINISH else "failed"
    except Exception as exc:
        print(f"  Full mode error: {exc}", file=sys.stderr)
        result["status"] = "error"

    result["wall_time"] = time.time() - start_time
    return result


# ---------------------------------------------------------------------------
# Patch extraction
# ---------------------------------------------------------------------------

def extract_patch(wt_path: str | Path, base_commit: str) -> str:
    """Extract git diff between base_commit and working tree as a patch.

    Excludes eval scaffolding files (.eval-overrides.sh, .issue.md, .tmp/,
    *.bak) that are not part of the actual code fix.
    """
    proc = subprocess.run(
        [
            "git", "diff", base_commit,
            "--", ".", ":!.eval-overrides.sh", ":!.issue.md", ":!.tmp/",
            ":!*.bak",
        ],
        cwd=str(wt_path),
        capture_output=True,
        text=True,
    )
    patch = proc.stdout.strip()
    if patch and not patch.endswith("\n"):
        patch += "\n"
    return patch


# ---------------------------------------------------------------------------
# Scoring via SWE-bench evaluator
# ---------------------------------------------------------------------------

def score_predictions(
    predictions_path: str,
    dataset_name: str = "princeton-nlp/SWE-bench_Lite",
    max_workers: int = 4,
    run_id: str = "agentize-eval",
) -> dict | None:
    """Invoke SWE-bench Docker evaluator on predictions JSONL.

    Returns parsed results dict, or None if results file not found.
    """
    cmd = [
        sys.executable, "-m", "swebench.harness.run_evaluation",
        "--dataset_name", dataset_name,
        "--predictions_path", predictions_path,
        "--max_workers", str(max_workers),
        "--run_id", run_id,
    ]
    _run(cmd)

    # Parse results from standard SWE-bench output location
    results_path = Path("evaluation_results") / run_id / "results.json"
    if results_path.exists():
        return json.loads(results_path.read_text(encoding="utf-8"))
    return None


# ---------------------------------------------------------------------------
# Metrics aggregation
# ---------------------------------------------------------------------------

def aggregate_metrics(results: list[dict]) -> dict:
    """Compute summary metrics from per-task result dicts."""
    completed = [r for r in results if r["status"] == "completed"]
    tokens = [r["tokens"] for r in completed if r.get("tokens", 0) > 0]
    times = [r["wall_time"] for r in completed if r.get("wall_time", 0) > 0]

    return {
        "total_tasks": len(results),
        "completed": len(completed),
        "timeouts": sum(1 for r in results if r["status"] == "timeout"),
        "errors": sum(1 for r in results if r["status"] == "error"),
        "failed": sum(1 for r in results if r["status"] == "failed"),
        "tokens_mean": sum(tokens) / len(tokens) if tokens else 0,
        "tokens_median": sorted(tokens)[len(tokens) // 2] if tokens else 0,
        "tokens_total": sum(tokens),
        "time_mean": sum(times) / len(times) if times else 0.0,
        "time_total": sum(times),
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    """CLI entry point for the SWE-bench evaluation harness."""
    parser = argparse.ArgumentParser(
        description="SWE-bench evaluation harness for agentize",
    )
    sub = parser.add_subparsers(dest="command")

    # -- run subcommand -----------------------------------------------
    run_p = sub.add_parser("run", help="Run end-to-end evaluation")
    run_p.add_argument("--dataset", default="princeton-nlp/SWE-bench_Lite")
    run_p.add_argument(
        "--instance-ids", nargs="*",
        help="Specific instance IDs to evaluate",
    )
    run_p.add_argument("--limit", type=int, help="Max tasks to run")
    run_p.add_argument(
        "--timeout", type=int, default=1800,
        help="Per-task timeout in seconds (default: 1800)",
    )
    run_p.add_argument(
        "--output-dir", default=".tmp/eval",
        help="Output directory for predictions and metrics",
    )
    run_p.add_argument(
        "--model", default="sonnet",
        help="Claude model to use (default: sonnet)",
    )
    run_p.add_argument(
        "--mode", choices=["raw", "full"], default="raw",
        help="Execution mode: raw (bare claude -p) or full (planning + FSM)",
    )
    run_p.add_argument(
        "--enable-review", action="store_true", default=False,
        help="Enable review stage in full mode",
    )
    run_p.add_argument(
        "--enable-simp", action="store_true", default=False,
        help="Enable simplification stage in full mode",
    )
    run_p.add_argument(
        "--max-iterations", type=int, default=10,
        help="Max FSM iterations in full mode (default: 10)",
    )
    run_p.add_argument(
        "--dry-run", action="store_true",
        help="Setup tasks without running implementation",
    )

    # -- score subcommand ---------------------------------------------
    score_p = sub.add_parser("score", help="Score existing predictions")
    score_p.add_argument("--predictions", required=True)
    score_p.add_argument("--dataset", default="princeton-nlp/SWE-bench_Lite")
    score_p.add_argument("--max-workers", type=int, default=4)
    score_p.add_argument("--run-id", default="agentize-eval")

    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        return 1

    if args.command == "run":
        return _cmd_run(args)
    elif args.command == "score":
        return _cmd_score(args)
    return 1


def _cmd_run(args) -> int:
    """Execute the ``run`` subcommand."""
    # Auto-append mode to output dir so raw/full don't overwrite each other
    base_dir = Path(args.output_dir)
    output_dir = base_dir / args.mode
    # Share repo cache across modes (clones are expensive)
    repos_dir = base_dir / "repos"
    worktrees_dir = output_dir / "worktrees"
    predictions_path = output_dir / "predictions.jsonl"
    metrics_path = output_dir / "metrics.json"

    output_dir.mkdir(parents=True, exist_ok=True)

    # Load tasks
    print(f"Loading tasks from {args.dataset}...")
    tasks = load_tasks(
        dataset_name=args.dataset,
        instance_ids=args.instance_ids,
        limit=args.limit,
    )
    print(f"Loaded {len(tasks)} tasks")

    if not tasks:
        print("No tasks to run.", file=sys.stderr)
        return 1

    results = []
    predictions = []

    for i, task in enumerate(tasks):
        instance_id = task["instance_id"]
        print(f"\n[{i + 1}/{len(tasks)}] {instance_id}")

        # Setup worktree
        print(f"  Setting up worktree...")
        wt_path = setup_worktree(task, repos_dir, worktrees_dir)
        overrides_path = write_overrides(wt_path, instance_id)
        print(f"  Worktree: {wt_path}")

        if args.dry_run:
            print(f"  [dry-run] Skipping implementation")
            results.append({
                "instance_id": instance_id,
                "status": "dry-run",
                "wall_time": 0.0,
                "tokens": 0,
            })
            continue

        # Run implementation
        print(f"  Running implementation (mode={args.mode}, timeout={args.timeout}s, model={args.model})...")
        if args.mode == "full":
            result = run_full_impl(
                wt_path, overrides_path, instance_id,
                task["problem_statement"],
                timeout=args.timeout, model=args.model,
                enable_review=args.enable_review,
                enable_simp=args.enable_simp,
                max_iterations=args.max_iterations,
            )
        else:
            result = run_impl(
                wt_path, overrides_path, instance_id,
                timeout=args.timeout, model=args.model,
            )
        results.append(result)
        print(f"  Status: {result['status']}, "
              f"Time: {result['wall_time']:.1f}s, "
              f"Tokens: {result['tokens']}")

        # Extract patch
        if result["status"] == "completed":
            patch = extract_patch(wt_path, task["base_commit"])
            if patch:
                predictions.append({
                    "instance_id": instance_id,
                    "model_patch": patch,
                    "model_name_or_path": f"agentize-{args.mode}-{args.model}",
                })
                print(f"  Patch: {len(patch)} bytes")
            else:
                print(f"  No changes detected")

    # Write predictions JSONL
    if predictions:
        with open(predictions_path, "w", encoding="utf-8") as f:
            for pred in predictions:
                f.write(json.dumps(pred) + "\n")
        print(f"\nPredictions written to {predictions_path}")

    # Write metrics
    if results:
        metrics = aggregate_metrics(results)
        metrics_path.write_text(
            json.dumps(metrics, indent=2) + "\n", encoding="utf-8",
        )
        print(f"Metrics written to {metrics_path}")
        _print_summary(metrics)

    return 0


def _cmd_score(args) -> int:
    """Execute the ``score`` subcommand."""
    print(f"Scoring predictions from {args.predictions}...")
    results = score_predictions(
        predictions_path=args.predictions,
        dataset_name=args.dataset,
        max_workers=args.max_workers,
        run_id=args.run_id,
    )
    if results:
        print(json.dumps(results, indent=2))
    else:
        print("No results found. Check SWE-bench evaluator output.", file=sys.stderr)
        return 1
    return 0


def _print_summary(metrics: dict) -> None:
    """Print a human-readable summary of evaluation metrics."""
    print("\n--- Evaluation Summary ---")
    print(f"Total tasks:  {metrics['total_tasks']}")
    print(f"Completed:    {metrics['completed']}")
    print(f"Failed:       {metrics['failed']}")
    print(f"Timeouts:     {metrics['timeouts']}")
    print(f"Errors:       {metrics['errors']}")
    if metrics["tokens_total"] > 0:
        print(f"Tokens total: {metrics['tokens_total']:,}")
        print(f"Tokens mean:  {metrics['tokens_mean']:,.0f}")
        print(f"Tokens median:{metrics['tokens_median']:,}")
    if metrics["time_total"] > 0:
        print(f"Time total:   {metrics['time_total']:.1f}s")
        print(f"Time mean:    {metrics['time_mean']:.1f}s")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a subprocess command, printing it for visibility."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check)


if __name__ == "__main__":
    raise SystemExit(main())
