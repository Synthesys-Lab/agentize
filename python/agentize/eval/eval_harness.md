# eval_harness.py

SWE-bench evaluation harness for measuring agentize implementation quality
against real-world software engineering tasks.

## Architecture Overview

A single-file, function-based pipeline with three logical layers:

1. **Ingestion**: Load tasks from HuggingFace (`load_tasks`)
2. **Execution**: Clone repos, create worktrees, run implementation (`setup_worktree`, `write_overrides`, `run_impl` or `run_full_impl`, `extract_patch`)
3. **Scoring**: Delegate to the SWE-bench Docker evaluator (`score_predictions`, `aggregate_metrics`)

Tasks run sequentially. No threading, no Pydantic, no Docker Python SDK.

## Dual-Mode Execution

The harness supports two execution modes via `--mode`:

| Mode | What runs | What it tests |
|------|-----------|---------------|
| `raw` | `claude -p` + bare bug report | The model alone (baseline) |
| `full` | Planning pipeline + FSM orchestrator | The agentize framework |

### Raw mode (default)

Invokes `claude -p` as a subprocess with the problem statement. This tests
how well the underlying model can fix bugs without any scaffolding.

### Full mode

Runs the agentize pipeline end-to-end:
1. **Planning phase**: `run_planner_pipeline()` generates a consensus plan from the SWE-bench problem statement
2. **Issue file**: The plan is written to `worktree/.tmp/issue-1.md` in the format `impl_stage_kernel` expects
3. **FSM orchestrator**: `run_fsm_orchestrator()` drives the kernel loop: impl → review → simp → PR → rebase → finish

The PR and rebase stages are handled via **kernel substitution**: instead of
creating a custom transition table (which `run_fsm_orchestrator()` doesn't
support), we replace `pr_stage_kernel` and `rebase_stage_kernel` with no-op
stubs that emit pass events. The production transition table is reused
unchanged — the FSM still traverses PR and rebase, but the kernels return
instantly.

### Timeout Enforcement

Both modes enforce the `--timeout` flag. Raw mode uses `subprocess.run(timeout=...)`
natively. Full mode runs the planning + FSM body in a daemon thread and joins
with a deadline — if the thread is still alive after `timeout` seconds, the task
is marked as `"timeout"` and the main loop moves to the next task. The daemon
thread is abandoned (acceptable because each task runs in an isolated worktree).

## Why a Single File

SWE-bench evaluation is a linear pipeline: load → setup → run → extract → score.
Splitting this across seven modules (as typical frameworks do) introduces coupling
without benefit when the entire pipeline runs in a single process. A single file
with well-named functions is easier to read, debug, and modify.

## Offline Execution via Shell Overrides

Each task runs in a git worktree with `AGENTIZE_SHELL_OVERRIDES` pointing to
a generated script that stubs `gh`, `wt`, and `git push`. This prevents the
impl pipeline from making network calls to GitHub during evaluation.

This reuses the existing override mechanism documented in `docs/envvar.md`
and tested in `tests/cli/test-lol-impl-stubbed.sh`.

## Prerequisites

| Dependency | Purpose | Install |
|------------|---------|---------|
| `datasets` | HuggingFace dataset loading | `pip install datasets` |
| `swebench` | Docker-based patch scoring | `pip install swebench` |
| Docker Engine | Container runtime for scoring | System package |
| `claude` CLI | Headless code generation | Anthropic installer |

## Usage

### Raw mode (baseline)

```bash
# Dry-run first
python -m agentize.eval.eval_harness run --mode raw --limit 1 --dry-run

# Single task
python -m agentize.eval.eval_harness run --mode raw \
    --instance-ids django__django-16527 \
    --model sonnet --timeout 1800
```

### Full mode (agentize framework)

```bash
# Single task with planning + FSM
python -m agentize.eval.eval_harness run --mode full \
    --instance-ids django__django-16527 \
    --model sonnet --timeout 3600

# With review and simplification stages enabled
python -m agentize.eval.eval_harness run --mode full \
    --limit 5 --enable-review --enable-simp --max-iterations 15
```

### Re-score existing predictions

```bash
python -m agentize.eval.eval_harness score \
    --predictions .tmp/eval/predictions.jsonl
```

## Prediction Format

Output follows the SWE-bench JSONL convention:

```json
{"instance_id": "django__django-16527", "model_patch": "diff --git ...", "model_name_or_path": "agentize-raw-sonnet"}
{"instance_id": "django__django-16527", "model_patch": "diff --git ...", "model_name_or_path": "agentize-full-sonnet"}
```

## Ramp-up Strategy

Run costs scale with task count and per-task timeout. Validate incrementally:

1. **1 task, dry-run**: Verify dataset loading and worktree setup
2. **1 task, real run**: Verify end-to-end patch generation
3. **5 tasks**: Check diverse repos, collect initial metrics
4. **50 tasks** (SWE-bench Lite subset): Benchmark token usage and accuracy
5. **300 tasks** (SWE-bench Lite full): Production benchmark
6. **1,865 tasks** (SWE-bench Pro): Final evaluation

## Platform Requirements

- SWE-bench Docker evaluation images are built for `linux/amd64`. On Apple
  Silicon Macs, use `--platform linux/amd64` or run scoring on an x86_64 VM.
- Bare repo clones cache at `<output-dir>/repos/`. First run clones ~41 repos
  (one per unique SWE-bench repository). Subsequent runs reuse the cache.
- Disk usage: ~5-10 GB for repos, ~1 GB per 100 worktrees.

## Cost Estimation

Per-task costs depend on the model and task complexity. Rough estimates:

| Model | Tokens/task (est.) | Cost/task (est.) | 300 tasks |
|-------|-------------------|------------------|-----------|
| Haiku | ~50K | ~$0.05 | ~$15 |
| Sonnet | ~100K | ~$0.50 | ~$150 |
| Opus | ~150K | ~$5.00 | ~$1,500 |

Always start with `--limit 1` to verify before scaling up.
