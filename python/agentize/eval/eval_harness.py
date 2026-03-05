"""Evaluation harness for agentize.

Single-file harness that loads benchmark tasks (SWE-bench or nginx), runs the
agentize impl pipeline against each task in an isolated git worktree, extracts
patches, and scores them.

Supports two benchmarks via ``--benchmark``:
  - swebench (default): SWE-bench Verified from HuggingFace, scored via Docker evaluator
  - nginx: curated nginx bug-fix tasks from nginx_tasks.json, scored via prove

Supports four execution modes:
  - raw:   baseline Claude via ``claude -p`` (tests the model alone)
  - impl:  FSM orchestrator only, no planning (tests the impl kernel loop)
  - full:  agentize planning pipeline + FSM orchestrator (tests the framework)
  - nlcmd: natural-language command planning via ``claude -p`` + FSM (tests NL orchestration)

All modes track per-task cost in USD via ``agentize.usage.MODEL_PRICING``.

Usage:
    python -m agentize.eval.eval_harness run --mode raw --limit 1 --dry-run
    python -m agentize.eval.eval_harness run --benchmark nginx --mode raw --limit 1
    python -m agentize.eval.eval_harness score --predictions .tmp/eval/predictions.jsonl
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path


# ---------------------------------------------------------------------------
# Cost tracking helpers
# ---------------------------------------------------------------------------

# Model short-name → full model ID mapping for cost lookups.
# Keys match the --model CLI values; values match MODEL_PRICING prefixes.
_MODEL_ID_MAP = {
    "sonnet": "claude-sonnet-4",
    "opus": "claude-opus-4",
    "haiku": "claude-haiku-4-5",
}


def _make_result(instance_id: str) -> dict:
    """Create a blank per-task result dict with cost fields."""
    return {
        "instance_id": instance_id,
        "status": "error",
        "wall_time": 0.0,
        "tokens": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "cost_usd": 0.0,
    }


def _compute_cost(input_tokens: int, output_tokens: int, model: str) -> float:
    """Compute estimated USD cost from token counts and model short-name.

    Falls back to 0.0 if the model is not in the pricing table.
    """
    from agentize.usage import match_model_pricing

    model_id = _MODEL_ID_MAP.get(model, model)
    rates = match_model_pricing(model_id)
    if not rates:
        return 0.0
    return (
        input_tokens * rates["input"] / 1_000_000
        + output_tokens * rates["output"] / 1_000_000
    )


def _parse_claude_usage(stdout: str, model: str) -> dict:
    """Parse ``claude -p --output-format json`` output for token/cost data.

    Returns a dict with keys: input_tokens, output_tokens, tokens, cost_usd.
    Returns zeroes on parse failure.
    """
    result = {"input_tokens": 0, "output_tokens": 0, "tokens": 0, "cost_usd": 0.0}
    if not stdout:
        return result
    try:
        data = json.loads(stdout)
        usage = data.get("usage", {})
        inp = usage.get("input_tokens", 0)
        out = usage.get("output_tokens", 0)
        result["input_tokens"] = inp
        result["output_tokens"] = out
        result["tokens"] = inp + out
        # Use model from JSON if available, else fall back to caller's model
        json_model = data.get("model", "")
        result["cost_usd"] = _compute_cost(inp, out, json_model or model)
    except (json.JSONDecodeError, KeyError):
        pass
    return result


# ---------------------------------------------------------------------------
# JSONL-based cost tracking for ACW modes
# ---------------------------------------------------------------------------


def _list_jsonl_files() -> set[str]:
    """Return the set of all JSONL file paths under ~/.claude/projects/."""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.exists():
        return set()
    return {str(p) for p in projects_dir.glob("**/*.jsonl")}


def _sum_jsonl_usage(paths: list[str]) -> dict:
    """Sum token usage and cost from a list of JSONL session files.

    Returns a dict with keys: input_tokens, output_tokens, cache_read,
    cache_write, tokens, cost_usd.
    """
    from agentize.usage import match_model_pricing

    totals = {
        "input_tokens": 0, "output_tokens": 0,
        "cache_read": 0, "cache_write": 0,
        "tokens": 0, "cost_usd": 0.0,
    }
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        if entry.get("type") == "assistant":
                            message = entry.get("message", {})
                            usage = message.get("usage", {})
                            inp = usage.get("input_tokens", 0)
                            out = usage.get("output_tokens", 0)
                            cache_read = usage.get("cache_read_input_tokens", 0)
                            cache_write = usage.get("cache_creation_input_tokens", 0)
                            if inp > 0 or out > 0:
                                totals["input_tokens"] += inp
                                totals["output_tokens"] += out
                                totals["cache_read"] += cache_read
                                totals["cache_write"] += cache_write
                                model_id = message.get("model", "")
                                rates = match_model_pricing(model_id)
                                if rates:
                                    non_cache = max(0, inp - cache_read - cache_write)
                                    totals["cost_usd"] += (
                                        non_cache * rates["input"] / 1_000_000
                                        + out * rates["output"] / 1_000_000
                                        + cache_read * rates["cache_read"] / 1_000_000
                                        + cache_write * rates["cache_write"] / 1_000_000
                                    )
                    except (json.JSONDecodeError, KeyError):
                        continue
        except (OSError, IOError):
            continue

    totals["tokens"] = totals["input_tokens"] + totals["output_tokens"]
    return totals


# ---------------------------------------------------------------------------
# Task loading
# ---------------------------------------------------------------------------

def load_tasks(
    dataset_name: str = "princeton-nlp/SWE-bench_Verified",
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


def load_nginx_tasks(
    task_file: str,
    instance_ids: list[str] | None = None,
    limit: int | None = None,
) -> list[dict]:
    """Load nginx benchmark tasks from a JSON file.

    Each task is a dict with keys: instance_id, repo, test_repo, base_commit,
    fix_commit, test_commit, problem_statement, test_files, modules_required.
    """
    with open(task_file, encoding="utf-8") as f:
        tasks = json.load(f)

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


def setup_nginx_worktree(
    task: dict,
    repos_dir: str | Path,
    worktrees_dir: str | Path,
) -> str:
    """Clone nginx source + test repos and create worktree at base_commit.

    Creates two directories under worktrees_dir:
      - <instance_id>/       — nginx source worktree at base_commit
      - <instance_id>__tests/ — nginx-tests clone at test_commit

    Returns the source worktree path.
    """
    repo = task["repo"]
    test_repo = task["test_repo"]
    instance_id = task["instance_id"]
    base_commit = task["base_commit"]
    test_commit = task.get("test_commit", "HEAD")

    repos_dir = Path(repos_dir).resolve()
    worktrees_dir = Path(worktrees_dir).resolve()

    # Clone nginx source bare repo (cache across tasks)
    bare_path = repos_dir / (repo.replace("/", "__") + ".git")
    if not bare_path.exists():
        bare_path.parent.mkdir(parents=True, exist_ok=True)
        _run(["git", "clone", "--bare",
              f"https://github.com/{repo}.git", str(bare_path)])

    # Create source worktree at base_commit (skip if exists for resume)
    wt_path = worktrees_dir / instance_id
    if not wt_path.exists():
        wt_path.parent.mkdir(parents=True, exist_ok=True)
        _run(["git", "-C", str(bare_path), "worktree", "prune"], check=False)
        _run(["git", "-C", str(bare_path), "worktree", "add",
              "--detach", str(wt_path), base_commit])

    # Write problem statement as .issue.md
    issue_path = wt_path / ".issue.md"
    if not issue_path.exists():
        issue_path.write_text(task["problem_statement"], encoding="utf-8")

    # Pre-configure nginx so scoring only needs `make`
    makefile = wt_path / "Makefile"
    if not makefile.exists():
        configure_args = ["./auto/configure"]
        for flag in task.get("modules_required", []):
            configure_args.append(flag)
        configure_args.append("--prefix=" + str(wt_path / "install"))
        print(f"  $ {' '.join(configure_args)}  (cwd={wt_path})")
        subprocess.run(configure_args, cwd=str(wt_path), check=False)

    # Clone nginx-tests repo (skip if exists for resume)
    tests_path = worktrees_dir / (instance_id + "__tests")
    if not tests_path.exists():
        tests_path.parent.mkdir(parents=True, exist_ok=True)
        _run(["git", "clone", f"https://github.com/{test_repo}.git",
              str(tests_path)])
        if test_commit != "HEAD":
            _run(["git", "-C", str(tests_path), "checkout", test_commit])

    return str(wt_path)


def _strip_todo_blocks(test_file: Path) -> None:
    """Remove TODO { ... } blocks from a Perl test file, keeping assertions.

    nginx-tests use TODO blocks with has_version() checks that make assertions
    into expected failures on older nginx versions. Stripping these blocks turns
    the assertions into real pass/fail checks regardless of nginx version.
    """
    content = test_file.read_text(encoding="utf-8")
    # Match: TODO: { \n local $TODO = ...; \n <assertions> \n }
    # Keep the assertions, remove the TODO wrapper
    pattern = (
        r'TODO:\s*\{\s*\n'           # opening: TODO: {
        r'\s*local\s+\$TODO\s*=[^;]+;\s*\n'  # local $TODO = ...;
        r'(.*?)\n'                   # assertions (captured)
        r'\s*\}'                     # closing }
    )
    content = re.sub(pattern, r'\1', content, flags=re.DOTALL)
    test_file.write_text(content, encoding="utf-8")


def score_nginx(
    wt_path: str,
    task: dict,
    tests_path: str,
) -> dict:
    """Compile nginx from worktree and score via prove.

    Steps:
    1. Run ./auto/configure with required modules
    2. Run make -j
    3. If compilation fails, return compile_failed
    4. Strip TODO blocks from test files so assertions are real
    5. Run prove with TEST_NGINX_BINARY pointing to compiled binary
    6. Return resolved=True if prove exits 0

    Returns a dict with status and resolved fields.
    """
    wt = Path(wt_path)
    tests = Path(tests_path)

    # Build configure command with required modules
    configure_args = ["./auto/configure"]
    for flag in task.get("modules_required", []):
        configure_args.append(flag)

    # Configure (skip if Makefile already exists from a previous configure)
    makefile = wt / "Makefile"
    print(f"  Compiling nginx...")
    if not makefile.exists():
        try:
            subprocess.run(
                configure_args, cwd=str(wt),
                capture_output=True, text=True, check=True, timeout=120,
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            print(f"  Configure failed: {e}", file=sys.stderr)
            return {"status": "compile_failed", "resolved": False}

    # Make (always rebuild to pick up source changes)
    import multiprocessing
    jobs = str(multiprocessing.cpu_count())
    try:
        subprocess.run(
            ["make", f"-j{jobs}"], cwd=str(wt),
            capture_output=True, text=True, check=True, timeout=300,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        print(f"  Make failed: {e}", file=sys.stderr)
        return {"status": "compile_failed", "resolved": False}

    # Verify binary exists
    binary = wt / "objs" / "nginx"
    if not binary.exists():
        print(f"  Binary not found at {binary}", file=sys.stderr)
        return {"status": "compile_failed", "resolved": False}

    # Reset test files from git (clean state for re-runs), then strip TODOs
    for test_file_name in task.get("test_files", []):
        test_file = tests / test_file_name
        if test_file.exists():
            subprocess.run(
                ["git", "checkout", test_file_name], cwd=str(tests),
                capture_output=True, check=False,
            )
            _strip_todo_blocks(test_file)

    # Run prove with the compiled binary
    env = os.environ.copy()
    env["TEST_NGINX_BINARY"] = str(binary.resolve())

    prove_cmd = ["prove", "-v"] + task.get("test_files", [])
    print(f"  Running: {' '.join(prove_cmd)}")
    try:
        proc = subprocess.run(
            prove_cmd, cwd=str(tests),
            env=env, capture_output=True, text=True, timeout=300,
        )

        # Parse TAP output for individual test results
        expected = task.get("expected_pass_tests", [])
        if expected:
            # Check specific named tests instead of overall exit code.
            # TAP format: "ok N - test name" or "not ok N - test name"
            tap_results = {}
            for line in proc.stdout.split("\n"):
                m = re.match(r"(ok|not ok)\s+\d+\s+-\s+(.+)", line)
                if m:
                    tap_results[m.group(2).strip()] = m.group(1) == "ok"
            resolved = all(tap_results.get(t, False) for t in expected)
            if not resolved:
                for t in expected:
                    status = "PASS" if tap_results.get(t, False) else "FAIL"
                    print(f"    {t}: {status}", file=sys.stderr)
        else:
            resolved = proc.returncode == 0
            if not resolved and proc.stdout:
                lines = proc.stdout.strip().split("\n")
                for line in lines[-5:]:
                    print(f"    {line}", file=sys.stderr)

        return {"status": "completed", "resolved": resolved}
    except subprocess.TimeoutExpired:
        print(f"  prove timed out", file=sys.stderr)
        return {"status": "completed", "resolved": False}


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
    env = _make_clean_env(overrides_path)

    start_time = time.time()
    result = _make_result(instance_id)

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

        usage = _parse_claude_usage(proc.stdout, model)
        result.update(usage)

        if proc.returncode != 0 and proc.stderr:
            print(f"  claude stderr: {proc.stderr[:200]}", file=sys.stderr)
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
    skip_planning: bool = False,
) -> dict:
    """Run the agentize pipeline against a task.

    When ``skip_planning`` is False (default), runs the full pipeline:
    5-agent planning debate followed by FSM orchestrator.

    When ``skip_planning`` is True, feeds the problem statement directly
    to the FSM orchestrator, bypassing the planning phase entirely.

    Uses kernel substitution to skip PR/rebase stages while reusing the
    production transition table unchanged. Enforces a wall-clock timeout
    via a daemon thread — if the pipeline exceeds ``timeout`` seconds the
    task is marked as timed-out and the main loop moves on.
    """
    start_time = time.time()
    result = _make_result(instance_id)

    # Snapshot JSONL file list before running — we'll sum only NEW files after
    files_before = _list_jsonl_files()
    if not skip_planning:
        result["cost_note"] = "cost estimated from new JSONL session files"

    # Run the pipeline body in a daemon thread so we can enforce a timeout.
    # A daemon thread is killed when the main thread moves on; this is
    # acceptable because each task runs in its own isolated worktree.
    exc_bucket: list[Exception] = []
    status_bucket: list[str] = []

    def _run_pipeline():
        try:
            status = _run_full_impl_body(
                wt_path, overrides_path, instance_id,
                problem_statement, model,
                enable_review, enable_simp, max_iterations,
                skip_planning=skip_planning,
            )
            status_bucket.append(status)
        except Exception as exc:
            exc_bucket.append(exc)

    worker = threading.Thread(target=_run_pipeline, daemon=True)
    worker.start()
    worker.join(timeout=timeout)

    if worker.is_alive():
        print(f"  Timeout after {timeout}s — moving on", file=sys.stderr)
        result["status"] = "timeout"
        result["wall_time"] = float(timeout)
    elif exc_bucket:
        print(f"  Full mode error: {exc_bucket[0]}", file=sys.stderr)
        result["status"] = "error"
        result["wall_time"] = time.time() - start_time
    else:
        result["status"] = status_bucket[0] if status_bucket else "error"
        result["wall_time"] = time.time() - start_time

    # Compute cost from NEW JSONL files only (created during this run)
    files_after = _list_jsonl_files()
    new_files = sorted(files_after - files_before)
    if new_files:
        usage = _sum_jsonl_usage(new_files)
        result["input_tokens"] = usage["input_tokens"]
        result["output_tokens"] = usage["output_tokens"]
        result["cache_read_tokens"] = usage["cache_read"]
        result["cache_write_tokens"] = usage["cache_write"]
        result["tokens"] = usage["tokens"]
        result["cost_usd"] = usage["cost_usd"]

    return result


def _run_full_impl_body(
    wt_path: str | Path,
    overrides_path: str,
    instance_id: str,
    problem_statement: str,
    model: str,
    enable_review: bool,
    enable_simp: bool,
    max_iterations: int,
    skip_planning: bool = False,
    plan_override: str | None = None,
) -> str:
    """Inner body of run_full_impl — runs planning + FSM, returns status string.

    When ``plan_override`` is provided, it is used as the plan text instead of
    running the planning pipeline.  This is used by nlcmd mode which generates
    the plan externally via ``claude -p``.
    """
    from agentize.workflow.api import Session
    from agentize.workflow.impl.checkpoint import create_initial_state
    from agentize.workflow.impl.orchestrator import run_fsm_orchestrator
    from agentize.workflow.impl.state import STAGE_FINISH, WorkflowContext

    wt = Path(wt_path)
    tmp_dir = wt / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    # Clean nesting guards so claude subprocesses can launch
    for var in _NESTING_VARS:
        os.environ.pop(var, None)
    os.environ["AGENTIZE_SHELL_OVERRIDES"] = overrides_path

    # Write issue file where impl_kernel expects it
    issue_file = tmp_dir / "issue-1.md"
    if plan_override:
        # Use externally-generated plan (nlcmd mode)
        issue_content = (
            f"# SWE-bench Task\n\n"
            f"## Problem Statement\n\n{problem_statement}\n\n"
            f"## Implementation Plan\n\n{plan_override}\n\n"
            f"## Instructions\n\nImplement the fix. Follow the plan. Make minimal changes.\n"
        )
    elif skip_planning:
        # Feed problem statement directly to the FSM — no planning phase
        issue_content = (
            f"# SWE-bench Task\n\n"
            f"## Problem Statement\n\n{problem_statement}\n\n"
            f"## Instructions\n\nImplement the fix. Make minimal changes.\n"
        )
    else:
        issue_content = run_planning_phase(problem_statement, tmp_dir, model)
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

    return "completed" if context.current_stage == STAGE_FINISH else "failed"


# ---------------------------------------------------------------------------
# NL-command mode: multi-agent planning via /ultra-planner or /mega-planner
# ---------------------------------------------------------------------------

# Supported planner commands and their dry-run invocations.
# ultra-planner: has native --dry-run --force-full (skips GH, forces full debate)
# mega-planner:  no --dry-run; GH calls are stubbed via eval overrides
_PLANNER_CMD_TEMPLATES = {
    "ultra-planner": "/ultra-planner --force-full --dry-run {problem_statement}",
    "mega-planner": "/mega-planner {problem_statement}",
}


def _find_consensus_plan(tmp_dir: Path) -> str:
    """Find the most recent consensus plan file in tmp_dir.

    The ultra-planner writes to ``issue-dry-run-<timestamp>-consensus.md``,
    the mega-planner writes to ``issue-<N>-consensus.md``.  We glob for
    any ``*-consensus.md`` and pick the newest.
    """
    candidates = sorted(
        tmp_dir.glob("*-consensus.md"),
        key=lambda p: p.stat().st_mtime,
    )
    if candidates:
        return candidates[-1].read_text(encoding="utf-8")
    return ""


def run_nlcmd_impl(
    wt_path: str | Path,
    overrides_path: str,
    instance_id: str,
    problem_statement: str,
    timeout: int = 3600,
    model: str = "sonnet",
    planning_model: str = "opus",
    planner_cmd: str = "ultra-planner",
    enable_review: bool = False,
    enable_simp: bool = False,
    max_iterations: int = 10,
) -> dict:
    """Run multi-agent NL planning command + FSM implementation.

    Phase 1: Invoke ``claude -p "/<planner_cmd> ..."`` which triggers the
    full multi-agent debate flow (understander -> bold-proposer -> critique
    + reducer -> consensus) via Claude Code's natural-language command
    orchestration — the same way ``wt spawn --headless`` does it.

    Phase 2: Read the consensus plan from ``.tmp/`` and feed it to the FSM
    orchestrator for implementation.

    Token tracking captures the **orchestrator session** tokens.  Subagent
    tokens (spawned via Task tool) run as separate processes and are not
    included — this is a known limitation noted in the result dict.

    Returns a result dict with combined cost from both phases.
    """
    start_time = time.time()
    result = _make_result(instance_id)
    result["planner_cmd"] = planner_cmd
    result["cost_note"] = (
        "orchestrator tokens tracked; subagent tokens not included "
        "(they run as separate claude processes via Task tool)"
    )

    wt = Path(wt_path)
    tmp_dir = wt / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    # Write the problem statement so agents can read it
    issue_path = wt / ".issue.md"
    if not issue_path.exists():
        issue_path.write_text(problem_statement, encoding="utf-8")

    # --- Phase 1: NL planning via the actual planner command ---
    env = _make_clean_env(overrides_path)

    template = _PLANNER_CMD_TEMPLATES.get(planner_cmd)
    if not template:
        print(f"  Unknown planner command: {planner_cmd}", file=sys.stderr)
        result["status"] = "error"
        result["wall_time"] = time.time() - start_time
        return result

    cmd_str = template.format(problem_statement=problem_statement)
    planning_timeout = timeout // 2  # reserve half the budget for impl

    print(f"  Phase 1: NL planning via '{planner_cmd}' (timeout={planning_timeout}s)",
          file=sys.stderr)

    plan_text = ""
    try:
        plan_proc = subprocess.run(
            ["claude", "-p", "--output-format", "json",
             "--model", planning_model, cmd_str],
            cwd=str(wt_path),
            env=env,
            capture_output=True,
            text=True,
            timeout=planning_timeout,
        )

        # Track orchestrator-level token usage
        plan_usage = _parse_claude_usage(plan_proc.stdout, planning_model)
        result["input_tokens"] += plan_usage["input_tokens"]
        result["output_tokens"] += plan_usage["output_tokens"]
        result["tokens"] += plan_usage["tokens"]
        result["cost_usd"] += plan_usage["cost_usd"]
        result["planning_tokens"] = plan_usage["tokens"]
        result["planning_cost_usd"] = plan_usage["cost_usd"]

        if plan_proc.returncode != 0:
            print(f"  NL planning failed (rc={plan_proc.returncode})", file=sys.stderr)
            if plan_proc.stderr:
                print(f"  stderr: {plan_proc.stderr[:500]}", file=sys.stderr)

        # Read the consensus plan from .tmp/ (written by the planner command)
        plan_text = _find_consensus_plan(tmp_dir)
        if plan_text:
            print(f"  Consensus plan found ({len(plan_text)} chars)", file=sys.stderr)
        else:
            # Fall back: try to extract plan from the JSON response body
            print("  No consensus file found; extracting from response", file=sys.stderr)
            if plan_proc.stdout:
                try:
                    plan_data = json.loads(plan_proc.stdout)
                    content = plan_data.get("content", [])
                    if isinstance(content, list):
                        plan_text = "\n".join(
                            block.get("text", "") for block in content
                            if isinstance(block, dict) and block.get("type") == "text"
                        )
                    elif isinstance(content, str):
                        plan_text = content
                    if not plan_text:
                        plan_text = plan_data.get("result", "")
                except (json.JSONDecodeError, KeyError):
                    pass

        if not plan_text:
            print("  No plan produced — falling back to raw problem statement",
                  file=sys.stderr)

    except subprocess.TimeoutExpired:
        # Even on timeout, check if a partial consensus was written
        plan_text = _find_consensus_plan(tmp_dir)
        if plan_text:
            print(f"  Planning timed out but partial consensus found ({len(plan_text)} chars)",
                  file=sys.stderr)
        else:
            result["status"] = "timeout"
            result["wall_time"] = time.time() - start_time
            return result

    # --- Phase 2: FSM impl with plan ---
    remaining_timeout = max(60, timeout - int(time.time() - start_time))
    print(f"  Phase 2: FSM impl (timeout={remaining_timeout}s)", file=sys.stderr)

    exc_bucket: list[Exception] = []
    status_bucket: list[str] = []

    def _run_impl():
        try:
            status = _run_full_impl_body(
                wt_path, overrides_path, instance_id,
                problem_statement, model,
                enable_review, enable_simp, max_iterations,
                skip_planning=True,
                plan_override=plan_text,
            )
            status_bucket.append(status)
        except Exception as exc:
            exc_bucket.append(exc)

    worker = threading.Thread(target=_run_impl, daemon=True)
    worker.start()
    worker.join(timeout=remaining_timeout)

    if worker.is_alive():
        print(f"  Impl timeout after {remaining_timeout}s", file=sys.stderr)
        result["status"] = "timeout"
        result["wall_time"] = float(timeout)
    elif exc_bucket:
        print(f"  NL impl error: {exc_bucket[0]}", file=sys.stderr)
        result["status"] = "error"
        result["wall_time"] = time.time() - start_time
    else:
        result["status"] = status_bucket[0] if status_bucket else "error"
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
    dataset_name: str = "princeton-nlp/SWE-bench_Verified",
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
    costs = [r["cost_usd"] for r in results if r.get("cost_usd", 0) > 0]
    input_tokens = [r["input_tokens"] for r in completed if r.get("input_tokens", 0) > 0]
    output_tokens = [r["output_tokens"] for r in completed if r.get("output_tokens", 0) > 0]

    return {
        "total_tasks": len(results),
        "completed": len(completed),
        "timeouts": sum(1 for r in results if r["status"] == "timeout"),
        "errors": sum(1 for r in results if r["status"] == "error"),
        "compile_failed": sum(1 for r in results if r["status"] == "compile_failed"),
        "failed": sum(1 for r in results if r["status"] == "failed"),
        "tokens_mean": sum(tokens) / len(tokens) if tokens else 0,
        "tokens_median": sorted(tokens)[len(tokens) // 2] if tokens else 0,
        "tokens_total": sum(tokens),
        "input_tokens_total": sum(input_tokens),
        "output_tokens_total": sum(output_tokens),
        "time_mean": sum(times) / len(times) if times else 0.0,
        "time_total": sum(times),
        "cost_total_usd": sum(costs),
        "cost_mean_usd": sum(costs) / len(costs) if costs else 0.0,
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
    run_p.add_argument(
        "--benchmark", choices=["swebench", "nginx"], default="swebench",
        help="Benchmark to run: swebench (default) or nginx",
    )
    run_p.add_argument("--dataset", default="princeton-nlp/SWE-bench_Verified")
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
        "--mode", choices=["raw", "impl", "full", "nlcmd"], default="raw",
        help=(
            "Execution mode: raw (bare claude -p), impl (FSM only), "
            "full (script planning + FSM), nlcmd (NL planning via claude -p + FSM)"
        ),
    )
    run_p.add_argument(
        "--planning-model", default="opus",
        help="Model for planning phase in nlcmd/full modes (default: opus)",
    )
    run_p.add_argument(
        "--planner-cmd", default="ultra-planner",
        choices=["ultra-planner", "mega-planner"],
        help="NL planner command for nlcmd mode (default: ultra-planner)",
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
    score_p = sub.add_parser("score", help="Score existing predictions (SWE-bench only)")
    score_p.add_argument("--predictions", required=True)
    score_p.add_argument("--dataset", default="princeton-nlp/SWE-bench_Verified")
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
    is_nginx = getattr(args, "benchmark", "swebench") == "nginx"
    if is_nginx:
        tasks_file = Path(__file__).parent / "nginx_tasks.json"
        print(f"Loading nginx tasks from {tasks_file}...")
        tasks = load_nginx_tasks(str(tasks_file), args.instance_ids, args.limit)
    else:
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
        if is_nginx:
            wt_path = setup_nginx_worktree(task, repos_dir, worktrees_dir)
        else:
            wt_path = setup_worktree(task, repos_dir, worktrees_dir)
        overrides_path = write_overrides(wt_path, instance_id)
        print(f"  Worktree: {wt_path}")

        if args.dry_run:
            print(f"  [dry-run] Skipping implementation")
            results.append(_make_result(instance_id) | {"status": "dry-run"})
            continue

        # Run implementation
        print(f"  Running implementation (mode={args.mode}, timeout={args.timeout}s, model={args.model})...")
        if args.mode == "nlcmd":
            result = run_nlcmd_impl(
                wt_path, overrides_path, instance_id,
                task["problem_statement"],
                timeout=args.timeout, model=args.model,
                planning_model=args.planning_model,
                planner_cmd=args.planner_cmd,
                enable_review=args.enable_review,
                enable_simp=args.enable_simp,
                max_iterations=args.max_iterations,
            )
        elif args.mode in ("full", "impl"):
            result = run_full_impl(
                wt_path, overrides_path, instance_id,
                task["problem_statement"],
                timeout=args.timeout, model=args.model,
                enable_review=args.enable_review,
                enable_simp=args.enable_simp,
                max_iterations=args.max_iterations,
                skip_planning=(args.mode == "impl"),
            )
        else:
            result = run_impl(
                wt_path, overrides_path, instance_id,
                timeout=args.timeout, model=args.model,
            )
        results.append(result)
        cost_str = f", Cost: ${result['cost_usd']:.4f}" if result.get("cost_usd") else ""
        print(f"  Status: {result['status']}, "
              f"Time: {result['wall_time']:.1f}s, "
              f"Tokens: {result['tokens']}{cost_str}")

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

                # Nginx: score immediately by compiling + running prove
                if is_nginx:
                    tests_path = worktrees_dir / (instance_id + "__tests")
                    score = score_nginx(wt_path, task, str(tests_path))
                    result.update(score)
                    print(f"  Nginx score: resolved={score.get('resolved', False)}")
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
    if metrics.get("compile_failed", 0) > 0:
        print(f"Compile fail: {metrics['compile_failed']}")
    if metrics["tokens_total"] > 0:
        print(f"Tokens total: {metrics['tokens_total']:,}")
        print(f"  Input:      {metrics['input_tokens_total']:,}")
        print(f"  Output:     {metrics['output_tokens_total']:,}")
        print(f"Tokens mean:  {metrics['tokens_mean']:,.0f}")
        print(f"Tokens median:{metrics['tokens_median']:,}")
    if metrics["time_total"] > 0:
        print(f"Time total:   {metrics['time_total']:.1f}s")
        print(f"Time mean:    {metrics['time_mean']:.1f}s")
    if metrics.get("cost_total_usd", 0) > 0:
        print(f"Cost total:   ${metrics['cost_total_usd']:.4f}")
        print(f"Cost mean:    ${metrics['cost_mean_usd']:.4f}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Env vars that prevent claude from launching inside an existing session.
_NESTING_VARS = ("CLAUDECODE", "CLAUDE_CODE_SESSION")


def _make_clean_env(overrides_path: str) -> dict[str, str]:
    """Build a subprocess env with nesting guards removed and overrides set."""
    env = os.environ.copy()
    for var in _NESTING_VARS:
        env.pop(var, None)
    env["AGENTIZE_SHELL_OVERRIDES"] = overrides_path
    return env


def _run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a subprocess command, printing it for visibility."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check)


if __name__ == "__main__":
    raise SystemExit(main())
