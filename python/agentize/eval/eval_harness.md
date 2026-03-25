# eval_harness.py

Evaluation harness for measuring agentize implementation quality against
real-world software engineering tasks across multiple benchmarks.

## Architecture Overview

A single-file, function-based pipeline with three logical layers:

1. **Ingestion**: Load tasks from HuggingFace (`load_tasks`) or JSON (`load_nginx_tasks`)
2. **Execution**: Clone repos, create worktrees, run implementation (`setup_worktree`/`setup_nginx_worktree`, `write_overrides`, `run_impl` or `run_full_impl`, `extract_patch`)
3. **Scoring**: Delegate to SWE-bench Docker evaluator (`score_predictions`) or compile+prove (`score_nginx`), then `aggregate_metrics`

Tasks run sequentially. No threading, no Pydantic, no Docker Python SDK.

## Multi-Benchmark Support

The harness supports two benchmarks via `--benchmark`:

| Benchmark | Source | Language | Scoring |
|-----------|--------|----------|---------|
| `swebench` (default) | HuggingFace dataset | Python | SWE-bench Docker evaluator |
| `nginx` | `nginx_tasks.json` | C | Compile + `prove` exit code |

For nginx, the harness clones two repos (nginx source + nginx-tests), creates
a worktree at the pre-fix commit, runs the AI to fix the bug, then compiles
nginx and runs the relevant test files via `prove`. TODO blocks in test files
are stripped so assertions become real pass/fail checks.

## Execution Modes

The harness supports four execution modes via `--mode`:

| Mode | What runs | What it tests | Cost tracking |
|------|-----------|---------------|---------------|
| `raw` | `claude -p` + bare bug report | The model alone (baseline) | Claude JSON usage (cache-tier aware when provided) |
| `impl` | FSM orchestrator only (no planning) | The impl kernel loop | JSONL session files |
| `full` | Planning pipeline + FSM orchestrator | The agentize framework | JSONL session files |
| `nlcmd` | NL planning via `claude -p` + FSM | NL orchestration | JSONL session files |

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

For JSONL-based modes (`impl`, `full`, `nlcmd`), cost is tracked via session file
diffing with per-session deduplication by `message.id` to avoid counting streamed
content blocks multiple times. Raw mode uses `claude -p` JSON output with
cache-tier-aware pricing when cache token fields are present.

Per-task costs depend on the model and task complexity. Rough estimates:

| Model | Tokens/task (est.) | Cost/task (est.) | 300 tasks |
|-------|-------------------|------------------|-----------|
| Haiku | ~50K | ~$0.05 | ~$15 |
| Sonnet | ~100K | ~$0.50 | ~$150 |
| Opus | ~150K | ~$5.00 | ~$1,500 |

Always start with `--limit 1` to verify before scaling up.

## Nginx Benchmark

The harness supports nginx/nginx-tests as a second benchmark via `--benchmark nginx`.
This runs the same 4-way mode comparison against C-language bug-fix tasks from the
nginx web server.

### Prerequisites (nginx-specific)

| Dependency | Purpose | Install |
|------------|---------|---------|
| C compiler (gcc/clang) | Compile nginx from source | System package |
| PCRE library | nginx regex support | `brew install pcre` / `apt install libpcre3-dev` |
| zlib | nginx gzip support | `brew install zlib` / `apt install zlib1g-dev` |
| OpenSSL | nginx SSL support | `brew install openssl` / `apt install libssl-dev` |
| Perl + prove | Run nginx test suite | Pre-installed on macOS/Linux |

The `Test::Nginx` module is shipped in the `lib/` directory of nginx-tests — no CPAN install needed.

### Usage

```bash
# Dry-run (validates task loading + worktree setup)
python -m agentize.eval.eval_harness run --benchmark nginx --mode raw --limit 1 --dry-run

# Single task
python -m agentize.eval.eval_harness run --benchmark nginx --mode raw \
    --instance-ids nginx__ec714d52 --timeout 1800

# Full 4-way comparison
for mode in raw impl full nlcmd; do
  python -m agentize.eval.eval_harness run --benchmark nginx --mode $mode --limit 5
done
```

### Task Format (nginx_tasks.json)

Each task specifies:
- `instance_id`: Unique identifier (e.g. `nginx__ec714d52`)
- `repo`: `nginx/nginx` (source repo)
- `test_repo`: `nginx/nginx-tests` (test suite repo)
- `base_commit`: Pre-fix commit in nginx source
- `fix_commit`: The commit that fixes the bug (for validation)
- `test_commit`: Corresponding commit in nginx-tests (usually `HEAD`)
- `problem_statement`: Bug description for the AI
- `test_files`: List of `.t` files to run
- `modules_required`: nginx configure flags needed (e.g. `--with-http_ssl_module`)

### Scoring

Scoring compiles nginx from the patched worktree and runs `prove` against
the specified test files. TODO blocks in test files are stripped so assertions
become real checks. Results:
- `completed` + `resolved=True`: all tests pass
- `completed` + `resolved=False`: some tests fail
- `compile_failed`: nginx fails to compile (distinct from error)
