# SWE-bench 20-Task Evaluation Report

**Date:** 2026-03-16 (costs corrected 2026-03-24)
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

## Appendix: Cost Efficiency

| Mode | Cost/task | Time/task | $/second | Tokens/task |
|------|-----------|-----------|----------|-------------|
| **cc.r** | $0.23 | 102s | $0.0023 | 5,133 |
| **cc.nl** | ~$0.45 | ~157s | ~$0.003 | ~6,188 |
| **cc.script** | $3.53 | 712s | $0.005 | 7,640 |
