# SWE-bench 20-Task Evaluation Report

**Date:** 2026-03-31 (costs corrected 2026-03-24)
**Benchmark:** SWE-bench Verified (20 astropy tasks)
**Modes tested:** cc.r (raw), cc.nl (nlcmd), cc.script (full with Claude consensus)
**Scoring:** SWE-bench Docker evaluator via podman

## Executive Summary

We scaled the SWE-bench evaluation from 5 to 20 tasks across three orchestration modes. The hypothesis **cc.r < cc.nl < cc.script** is **partially confirmed**: script orchestration (cc.script) resolves the most tasks at 60%, followed by NL orchestration (cc.nl) at 55%, and raw (cc.r) at 50%. Planning provides a consistent +5-10pp improvement — cc.script costs **~15x more** than cc.r for a 10pp gain.

## Results

### Resolve Rates

| Mode |  name | Resolved | Rate | Cost | Time |
|------|-------------|----------|------|------|------|
| `--mode raw` | **cc.r** | 10/20 | 50% | $4.64 | 34 min |
| `--mode nlcmd` | **cc.nl** | 11/20 | 55% | ~$8.94* | ~52 min* |
| `--mode full` | **cc.script** | 12/20 | 60% | $70.62 | 3.9 hrs |

*\*cc.nl cost/time estimated from 6 measured tasks (resume overwrite lost first 14 tasks' metrics).*

> **Cost correction note (2026-03-24):** Original costs ($1.47 cc.r, $195.30 cc.script) were inaccurate due to two bugs: (1) raw mode ignored cache-tier pricing, undercounting by ~3x; (2) JSONL-based modes double-counted streaming content blocks, overcounting by ~1.7x. See [#982](https://github.com/Synthesys-Lab/agentize/issues/982). Re-run with fixed cost tracking on 2026-03-24.

### Per-Instance Results

| Instance | cc.r | cc.nl | cc.script |
|----------|------|-------|-----------|
| astropy-12907 | PASS | PASS | PASS |
| astropy-13033 | FAIL | FAIL | FAIL |
| astropy-13236 | FAIL | FAIL | FAIL |
| astropy-13398 | FAIL | FAIL | FAIL |
| astropy-13453 | PASS | PASS | PASS |
| astropy-13579 | PASS | PASS | PASS |
| astropy-13977 | FAIL | FAIL | FAIL |
| astropy-14096 | PASS | PASS | PASS |
| astropy-14182 | FAIL | FAIL | FAIL |
| astropy-14309 | PASS | PASS | PASS |
| **astropy-14365** | FAIL | FAIL | **PASS** |
| astropy-14369 | FAIL | FAIL | FAIL |
| astropy-14508 | PASS | PASS | PASS |
| astropy-14539 | PASS | PASS | PASS |
| astropy-14598 | FAIL | FAIL | FAIL |
| astropy-14995 | PASS | PASS | PASS |
| **astropy-7166** | FAIL | **PASS** | **PASS** |
| astropy-7336 | PASS | PASS | PASS |
| astropy-7606 | FAIL | FAIL | FAIL |
| astropy-7671 | PASS | PASS | PASS |

### Token Usage & Timing

| Mode | Tokens total | Tokens mean | Time total | Time mean |
|------|-------------|-------------|------------|-----------|
| **cc.r** | 102,658 | 5,133 | 2,034s (34 min) | 102s |
| **cc.nl** | ~123,763* | ~6,188* | ~3,134s* (~52 min) | ~157s* |
| **cc.script** | 152,796 | 7,640 | 14,241s (3.9 hrs) | 712s |

### Phase Timing Breakdown (5-task sample, 2026-04-07)

| Task | Planning | Impl | Total | Planning % | Timed out? |
|------|----------|------|-------|------------|------------|
| astropy-12907 | 600s | 55s | 655s | 92% | Yes (600s cap) |
| astropy-13033 | 488s | 83s | 570s | 86% | No |
| astropy-13236 | 369s | 280s | 649s | 57% | No |
| astropy-13398 | 513s | 484s | 998s | 51% | No |
| astropy-13453 | 600s | 47s | 647s | 93% | Yes (600s cap) |
| **Mean** | **514s** | **190s** | **704s** | **73%** | **2/5 (40%)** |

Key observations:
- Planning accounts for **51-93%** of total task time (mean 73%)
- Implementation is fast: mean 190s (3.2 min) per task
- 2/5 tasks hit the 600s planning timeout — typically when understander or bold-proposer runs long
- Per-agent timing: understander 48-292s, bold 72-347s, critique+reducer 62-108s (parallel), consensus 89-253s

## Analysis

### Finding 1: cc.r < cc.nl < cc.script confirmed (barely)

The ordering holds but the margins are thin:

| Comparison | Resolve delta | Cost delta |
|---|---|---|
| cc.nl vs cc.r | +1 task (+5pp) | ~2x more ($8.94 vs $4.64) |
| cc.script vs cc.nl | +1 task (+5pp) | ~8x more ($70.62 vs $8.94) |
| cc.script vs cc.r | +2 tasks (+10pp) | **~15x more** ($70.62 vs $4.64) |

Each step up in orchestration complexity solves exactly one additional task. The cost scaling is superlinear — diminishing returns at increasing cost, though the ~15x ratio is much more reasonable than originally reported.

### Finding 2: A core of 10 tasks is "easy" — all modes solve them

All three modes agree on 10 tasks (50%): astropy-12907, 13453, 13579, 14096, 14309, 14508, 14539, 14995, 7336, 7671. These are likely straightforward bugs where even raw `claude -p` can produce the right fix.

### Finding 3: A core of 8 tasks is "hard" — no mode solves them

All three modes fail on 8 tasks (40%): astropy-13033, 13236, 13398, 13977, 14182, 14369, 14598, 7606. These are beyond what current orchestration can address, regardless of planning sophistication.

### Finding 4: The interesting zone is 2 tasks (10%)

Only 2 tasks differentiate the modes:

| Task | cc.r | cc.nl | cc.script | What helps |
|------|------|-------|-----------|------------|
| **astropy-7166** | FAIL | PASS | PASS | Any planning helps |
| **astropy-14365** | FAIL | FAIL | PASS | Only script planning helps |

- **astropy-7166**: Both planning modes solve it, raw doesn't. Planning provides enough context to find the right approach.
- **astropy-14365**: Only the 5-agent debate (cc.script) solves it. The NL planning in cc.nl is insufficient — the structured critique/reducer/consensus pipeline catches something the single-shot NL planner misses.

### Finding 5: cc.nl is the best cost-performance tradeoff

| Mode | $/resolved task | Marginal cost per extra task |
|------|----------------|------------------------------|
| **cc.r** | $0.46 | — |
| **cc.nl** | $0.81 | ~$4.30 for +1 task |
| **cc.script** | $5.89 | ~$61.68 for +1 task over cc.nl |

cc.nl gets 55% resolve rate at ~$9 total — 8x cheaper than cc.script for only 1 fewer resolved task. The marginal cost of cc.script's extra task (astropy-14365) is ~$62.

### Finding 6: Scaling from 5 to 20 tasks changed the picture

| Mode | 5-task rate | 20-task rate | Delta |
|------|-----------|-------------|-------|
| cc.r | 20% (1/5) | 50% (10/20) | +30pp |
| cc.script | 40% (2/5) | 60% (12/20) | +20pp |

The 5-task sample was pessimistic — the first 5 astropy tasks happened to be harder than average. At 20 tasks, raw mode's 50% baseline is much stronger, and the relative advantage of planning shrinks from +20pp to +10pp.

## Limitations

1. **Single repository** — All 20 tasks are from astropy. Results may not generalize to other Python projects or languages.
2. **cc.nl metrics estimated** — Resume bug overwrote first 14 tasks' cost/time data. Cost extrapolated from 6 measured tasks.
3. **codex.script not completed** — Codex API rate limits prevented completing the 20-task run (only 3/20 finished). Cannot compare cc.script vs codex.script at this scale.
4. **Single run** — No repeated trials to measure variance. The cc.r and cc.script re-runs (2026-03-24) are on newer model versions and may differ in resolve rates.
5. **No impl mode** — `--mode impl` was not run at 20-task scale for this report.
6. **cc.nl not re-run** — cc.nl costs were not re-measured with the corrected cost tracking; the ~$8.94 figure remains an estimate from the original run.

## Recommendations

1. **Use cc.nl as default** — best cost-performance ratio (55% at ~$9 vs 60% at $71).
2. **Use cc.script for high-stakes tasks** — when correctness matters more than cost, the extra ~$62/task buys +5pp.
3. **Complete codex.script evaluation** — needed to test the hypothesis cc.script ≈ codex.script.
4. **Investigate the 8 hard-fail tasks** — root-cause analysis may reveal systematic pipeline gaps.
5. **Expand to other repositories** — astropy-only evaluation limits generalizability.

## Appendix A: Cost Efficiency

| Mode | Cost/task | Time/task | $/second | Tokens/task |
|------|-----------|-----------|----------|-------------|
| **cc.r** | $0.23 | 102s | $0.0023 | 5,133 |
| **cc.nl** | ~$0.45 | ~157s | ~$0.003 | ~6,188 |
| **cc.script** | $3.53 | 712s | $0.005 | 7,640 |

## Appendix B: Model-Level Cost Breakdown (2026-03-25)

### Raw Opus Baseline

Running raw mode with opus instead of sonnet validates cost proportionality:

| Mode | Model | Tokens | Cost | Cost/task | Time |
|------|-------|--------|------|-----------|------|
| `--mode raw` | sonnet | 102,658 | $4.64 | $0.23 | 34 min |
| `--mode raw` | opus | 66,139 | $27.32 | $1.37 | 49 min |
| `--mode full` | opus plan + sonnet impl | 152,796 | $70.62 | $3.53 | 3.9 hrs |

**Key insight:** Raw opus costs $27.32 — the 5.9x ratio vs raw sonnet ($4.64) matches the ~5x opus/sonnet pricing difference. Full mode's $70.62 breaks down as: raw opus baseline ($27) + planning pipeline overhead (~$43). The planning overhead is ~1.6x the raw opus cost, not the 15x it appears when comparing against raw sonnet.

### Codex Implementation Backend — Iteration Loop Bug

Running full mode with `--planner-backend claude:opus --impl-backend codex:gpt-5.2-codex` revealed a critical iteration bug. On task 1 (astropy-12907), the Codex implementation agent failed to produce the FSM completion marker, causing the harness to loop:

```
Iteration 1: impl-iter-1 (codex:gpt-5.2-codex) runs 83s → "completion marker missing"
Iteration 2: impl-iter-2 (codex:gpt-5.2-codex) runs 158s → "completion marker missing"
Iteration 3: impl-iter-3 (codex:gpt-5.2-codex) runs 81s  → "completion marker missing"
Iteration 4: impl-iter-4 (codex:gpt-5.2-codex) runs 193s → "completion marker missing"
Iteration 5: (killed by user)
```

The Codex backend produced the correct patch in iteration 1 but never emitted the completion signal. Each subsequent iteration found "no changes to commit" yet still burned ~100-200s. This multi-iteration loop is the likely cause of unexpectedly long run times when using Codex as the implementation backend. The sonnet implementation backend consistently completes in exactly 1 iteration across all 20 tasks.

### nlcmd Mode — Planning Timeout Analysis (2026-03-25)

Re-running nlcmd with corrected cost tracking revealed that 7/20 tasks (35%) consistently timeout during Phase 1 (NL planning via `claude -p "/ultra-planner"`), even across two attempts with the 900s planning budget:

| Attempt | Completed | Timed out | Cost |
|---------|-----------|-----------|------|
| Run 1 (20 tasks) | 10 | 10 | $101.22 |
| Run 2 (10 retried) | 3 | 7 | $57.85 |
| **Combined** | **13** | **7** | **$159.07** |

The nlcmd mode is paradoxically the most expensive ($159 total) due to timeout waste — the timed-out planning phases still consume tokens and cost without producing patches. The 7 persistently-failing tasks (13236, 13398, 13977, 14369, 14508, 14598, 7671) suggest the `claude -p` NL dispatch adds overhead that pushes the 5-agent debate past the 900s budget.
