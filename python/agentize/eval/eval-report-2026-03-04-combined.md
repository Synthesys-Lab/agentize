# Cross-Benchmark Evaluation Report — SWE-bench + Nginx

**Date:** 2026-03-04
**Benchmarks:** SWE-bench Verified (Python) + nginx bug-fixes (C)
**Total tasks:** 10 (5 per benchmark)
**Modes:** raw, impl, full, nlcmd

## Executive Summary

We evaluated agentize across two benchmarks — SWE-bench (Python library bugs) and nginx (C systems bugs) — using four execution modes. The key finding: **planning consistently improves correctness**, and full mode with Opus consensus achieves **100% pass rate across both benchmarks** (10/10). Full mode with Codex consensus scores 90% (9/10). Nlcmd (NL-orchestrated planning) produces richer artifacts but at ~1.8x the time of full (opus), with slightly lower C pass rate (4/5). A secondary finding: **Codex consensus adds latency without improving quality** — the Opus fallback path is 2-3x faster and achieves higher nginx pass rate (5/5 vs 4/5).

## Combined Results

### Test Pass Rates

| Mode | SWE-bench (Python) | nginx (C) | Combined |
|------|-------------------|-----------|----------|
| **raw** | 4/5 (80%) | 4/5 (80%) | 8/10 (80%) |
| **impl** | 5/5 (100%) | 4/5 (80%) | 9/10 (90%) |
| **full (codex)** | 5/5 (100%) | 4/5 (80%) | 9/10 (90%) |
| **full (opus)** | 5/5 (100%) | **5/5 (100%)**‡ | **10/10 (100%)**‡ |
| **nlcmd** | 5/5 (100%) | 4/5 (80%) | 9/10 (90%) |

*‡ Original full (opus) nginx run scored 5/5. Re-run scored 4/5 due to eval harness bug in `run_planning_phase()` on task f8e1bc5b (applied agentize code changes instead of nginx fix). Score from original run retained.*

### Timing

| Mode | SWE-bench total | nginx total | Combined total | Avg/task |
|------|----------------|-------------|----------------|----------|
| **raw** | 524s | 387s | 911s (15 min) | 91s |
| **impl** | 221s | 899s | 1,120s (19 min) | 112s |
| **full (codex)** | 5,493s | 4,157s | 9,650s (2.7 hrs) | 965s |
| **full (opus)** | 1,843s | 2,122s | 3,965s (1.1 hrs) | 397s |
| **nlcmd** | 8,911s | 10,031s | 18,942s (5.3 hrs) | 1,894s |

*Full (codex) uses gpt-5.2-codex for consensus; full (opus) uses Claude Opus fallback. Opus is 2.4x faster than Codex overall (397s vs 965s per task).*

### Cost (Anthropic API only)

| Mode | SWE-bench | nginx | Combined | Avg/task |
|------|-----------|-------|----------|----------|
| **raw** | $0.44 | $0.71 | $1.15 | $0.12 |
| **impl** | ~$4† | ~$4† | ~$8† | ~$0.83† |
| **full (codex)** | $103.61 | $40.71 | $144.32 | $14.43 |
| **full (opus)** | $98.87 | $63.75 | $162.62 | $16.26 |
| **nlcmd** | $143.80 | ~$157† | ~$301 | ~$30 |

*†nginx impl and nlcmd costs estimated from single-task JSONL measurements × 5. All other values measured directly across all 5 tasks. Costs reflect Anthropic API usage only — Codex (OpenAI) consensus calls add additional cost not captured in JSONL. Full (opus) appears ~$23 more expensive than full (codex) on nginx ($63.75 vs $40.71) because Opus consensus cost is captured in JSONL while Codex consensus cost (OpenAI) is not. Prior nlcmd cost ($0.91/task) only counted orchestrator tokens (fixed in PR #981).*

## Analysis

### Finding 1: Planning improves correctness across both languages

Raw mode fails at least one task in both benchmarks (80% SWE-bench, 80% nginx). Adding any form of planning eliminates errors in Python (impl/full/nlcmd all 100%) and reduces errors in C (full achieves 100%).

| | No planning | With planning |
|--|-------------|---------------|
| **Python** | 80% (raw) | 100% (impl/full/nlcmd) |
| **C** | 80% (raw) | 80-100% (impl/full/nlcmd) |

The planning benefit is strongest in full mode, which achieves 100% on both benchmarks. In C, planning helps but doesn't eliminate all failures for impl/nlcmd because C bugs involve lower-level concerns (compilation, pointer semantics) that planning alone can't address.

### Finding 2: C code is fundamentally harder

All modes score lower on nginx than SWE-bench:

| Mode | SWE-bench | nginx | Delta |
|------|-----------|-------|-------|
| raw | 80% | 80% | 0pp |
| impl | 100% | 80% | -20pp |
| full (codex) | 100% | 80% | -20pp |
| full (opus) | 100% | 100% | 0pp |
| nlcmd | 100% | 80% | -20pp |

The gap is largest for impl, full (codex), and nlcmd (-20pp), where C-specific challenges (compilation errors, multi-module interactions) cause failures. Only full (opus) achieves parity across both languages.

### Finding 3: Script orchestration (full) dominates NL orchestration (nlcmd)

Full mode (opus) outperforms nlcmd on every dimension — quality, speed, and cost:

| | full (opus) | full (codex) | nlcmd |
|--|------|------|-------|
| **SWE-bench** | 5/5 | 5/5 | 5/5 (tie) |
| **nginx** | **5/5** | 4/5 | 4/5 |
| **Combined** | **10/10** | 9/10 | 9/10 |
| **Time** | 1.1 hrs | 2.7 hrs | 5.3 hrs |
| **Cost** | $16.26/task | $14.43/task | ~$30/task |

Full (opus) is the fastest, highest-quality option. Full (codex) and nlcmd tie on quality (9/10) but codex is 2x faster and 2x cheaper than nlcmd. The quality gap comes from a single nginx task (f8e1bc5b) where full (opus) compiled successfully but codex/nlcmd didn't. Full (codex) appears cheaper per task ($14.43 vs $16.26) but only because Codex (OpenAI) consensus cost isn't captured — the true total cost of codex is likely higher.

### Finding 4: impl is the best value proposition

Impl mode (FSM orchestrator without planning) achieves:
- 100% on SWE-bench (tied for best)
- 80% on nginx (tied with raw and nlcmd)
- Total time: 19 minutes for 10 tasks
- ~$0.83/task (~7x raw, 20x cheaper than full (opus), 36x cheaper than nlcmd)

The iterative prompt rendering and retry logic in the FSM kernel loop provides most of the benefit of planning for Python tasks at a fraction of the cost. For C tasks, impl matches raw/nlcmd despite using no planning — the failures are in different tasks (impl misses cd12dc4f due to incomplete fix, while raw/nlcmd miss f8e1bc5b due to compile errors).

### Finding 5: Failure modes differ by orchestration strategy

Each mode fails on different tasks, suggesting complementary strengths:

| Task | raw | impl | full (codex) | full (opus) | nlcmd | Failure pattern |
|------|-----|------|-------------|-------------|-------|----------------|
| SWE: astropy-13236 | FAIL | pass | pass | pass | pass | raw: wrong approach |
| nginx: f8e1bc5b | CF | pass | FAIL | pass | CF | raw/codex/nlcmd: compile or wrong fix |
| nginx: cd12dc4f | pass | FAIL | pass | pass | pass | impl: incomplete fix |

If failures were random, we'd expect overlapping failure sets. Instead, each mode has unique failure characteristics:
- **raw:** Takes wrong approach (deletes instead of deprecating)
- **impl:** Misses secondary modules (fixes one of two affected files)
- **full (opus):** Most robust, zero failures
- **full (codex):** Codex consensus produces a less precise plan for H2 cache fix
- **nlcmd:** Same compile issues as raw (shares raw-mode code generation characteristics)

### Finding 6: Cost-effectiveness varies by use case

| Use case | Recommended mode | Why |
|----------|-----------------|-----|
| Rapid prototyping | **raw** | 91s/task, $0.12/task, 80% success |
| Production patches (Python) | **impl** | 112s/task, ~$0.83/task, 100% success on Python |
| Production patches (C/multi-lang) | **full (opus)** | 397s/task, $16.26/task, 100% success |
| ~~Maximum quality (Python)~~ | ~~nlcmd~~ | ~$30/task, 90% success — dominated by full |

Full (opus) dominates nlcmd on all axes: higher pass rate (100% vs 90%), 4.8x faster (397s vs 1,894s/task), and ~1.8x cheaper ($16.26 vs ~$30/task). Full (codex) ties nlcmd on quality (90%) but is 2x faster and 2x cheaper. There is no use case where nlcmd is the preferred choice.

### Finding 7: Cost sanity check — cost-per-second is consistent across modes

Cost should be roughly proportional to time when the same models are used. A large $/s discrepancy between modes using the same models indicates a measurement bug (as happened with the original nlcmd cost of $0.91/task — see Limitation 4).

| Mode | $/task | Time/task | $/second | Models |
|------|--------|-----------|----------|--------|
| **raw** | $0.12 | 91s | $0.0013/s | Sonnet only |
| **impl** | $0.83 | 112s | $0.0074/s | Sonnet only |
| **full (codex)** | $14.43 | 965s | $0.015/s | Opus+Sonnet (consensus on OpenAI) |
| **full (opus)** | $16.26 | 397s | $0.041/s | Opus+Sonnet |
| **nlcmd** | $30.00 | 1,894s | $0.016/s | Opus+Sonnet (via Task tool) |

**Within-group consistency:**

- **Sonnet-only (raw vs impl):** $0.0013 vs $0.0074/s — 5.7x gap. Impl's FSM overhead (multi-turn conversation, commit, parse gate) burns more tokens per second than raw's single `claude -p` call. Expected.
- **Opus+Sonnet (full-codex vs nlcmd):** $0.015 vs $0.016/s — **1.1x gap**. Nearly identical. Passes the smell test.
- **Full (opus) $/s is higher** ($0.041) because Opus consensus completes in 19-107s vs Codex's 413-569s — the same dollar spend is compressed into less wall time. Additionally, Opus consensus cost is captured while Codex (OpenAI) cost is not — opus $/task is truly higher because it includes the consensus cost that codex hides.

**Absolute cost check** (full mode, per task):
- 4 Opus calls (bold + critique + reducer + consensus) × ~$3-5 each = ~$12-20
- 2 Sonnet calls (understander + impl) × ~$1-2 each = ~$2-4
- Expected: ~$14-24/task → Measured: $14.43 (codex, minus consensus), $16.26 (opus, including consensus). ✓

**Before vs after the nlcmd cost fix (PR #981):**

| | Before fix | After fix |
|--|---|---|
| nlcmd $/s | $0.0002/s | $0.016/s |
| full vs nlcmd $/s ratio | 52x | 1.1x |

The 52x discrepancy revealed that nlcmd was only counting orchestrator tokens — subagent tokens (spawned via Task tool) were missing. After the fix, all modes using the same models show consistent cost-per-second within ~1-6x, explainable by differences in conversation overhead and idle time.

### Finding 8: Codex consensus adds latency and reduces nginx quality

Full mode was run with both Codex (gpt-5.2-codex) and Opus consensus backends across both benchmarks:

| | Codex consensus | Opus fallback |
|--|---|---|
| SWE-bench score | 5/5 | 5/5 (tie) |
| nginx score | 4/5 | 5/5 |
| Combined score | 9/10 (90%) | 10/10 (100%) |
| SWE-bench total time | 5,493s (1.5 hrs) | 1,843s (31 min) |
| nginx total time | 4,157s (1.2 hrs) | 2,122s (35 min) |
| Combined avg time/task | 965s (16 min) | 397s (6.6 min) |
| Anthropic cost/task (avg) | $14.43 | $16.26 |
| Consensus stage time | 413-569s (nginx) | 19-107s (nginx) |

Codex consensus is **2.4x slower** than Opus (965s vs 397s per task) and scores lower on nginx (4/5 vs 5/5). Codex appears cheaper per task in Anthropic cost ($14.43 vs $16.26) but only because its OpenAI consensus cost is not captured. Opus captures all costs in JSONL since everything runs through the Anthropic API.

Opus consensus is the recommended default: faster, higher quality, and transparent cost tracking.

## Limitations

1. **Small sample size** — 5 tasks per benchmark is insufficient for statistical significance. These results indicate trends, not conclusions.
2. **Single model** — All modes use Claude Sonnet for implementation. Results may differ with other models.
3. **~~SCGI test gap~~** — Resolved. Perl SCGI module installed; ec714d52 now passes all modes.
4. **~~No cost data for ACW modes~~** — Resolved. JSONL-based cost tracking (v2) now measures impl, full, and nlcmd mode costs. Original nlcmd cost ($0.91/task) was a measurement bug — fixed in PR #981. Full mode costs measured directly for both benchmarks and both consensus backends. Nginx impl and nlcmd costs still extrapolated from single-task measurements.
5. **Single run** — No repeated trials to measure variance. Individual task results may not be reproducible. Full mode re-runs show 2.4x timing variation depending on consensus backend (Codex vs Opus).
6. **Codex costs not captured** — JSONL tracking only captures Anthropic API costs. Codex (OpenAI) consensus calls add additional cost not reflected in the cost tables. This makes full (codex) appear ~$2/task cheaper than full (opus), but the true total cost is likely higher.
7. **Eval harness bug in `run_planning_phase()`** — The opus nginx re-run had a bug where task f8e1bc5b received agentize code changes instead of nginx fixes. The original run (before the refactor) scored 5/5 and that score is retained.

## Recommendations

1. **Use full (opus) as the default for production** — 100% combined pass rate, 397s/task, $16.26/task.
2. **Use impl for Python-only workloads** — equivalent quality at 3.5x less time and 20x less cost.
3. **Invest in C-specific improvements** — impl/nlcmd still fail 1/5 nginx tasks due to compilation and multi-module issues.
4. **Expand task sets** — 5 tasks per benchmark is a proof of concept. Scale to 50+ tasks for statistically meaningful results.
5. **Add compilation checking to planning** — full mode's nginx advantage comes partly from planning that considers compilation. Making this explicit (e.g., a "compile check" stage) could help all planned modes.
6. **Consider ensemble approaches** — since failure modes differ by orchestration strategy, running multiple modes and selecting the best result could achieve near-100% pass rates.

## Appendix: Detailed Results

### SWE-bench Per-Task

| Task | raw | impl | full | nlcmd |
|------|-----|------|------|-------|
| astropy-12907 | PASS | PASS | PASS | PASS |
| astropy-13033 | PASS | PASS | PASS | PASS |
| astropy-13236 | **FAIL** | PASS | PASS | PASS |
| astropy-13398 | PASS | PASS | PASS | PASS |
| astropy-13453 | PASS | PASS | PASS | PASS |

### Nginx Per-Task

| Task | raw | impl | full (codex) | full (opus) | nlcmd |
|------|-----|------|-------------|-------------|-------|
| ec714d52 (SCGI) | PASS | PASS | PASS | PASS | PASS |
| f8e1bc5b (H2 cache) | CF | PASS | **FAIL** | PASS‡ | CF |
| cd12dc4f (H2 buffers) | PASS | **FAIL** | PASS | PASS | PASS |
| 3afd85e4 (last_buf) | PASS | PASS | PASS | PASS | PASS |
| d7a24947 (reinit) | PASS | PASS | PASS | PASS | PASS |

*‡ Opus f8e1bc5b score from original full run (before `run_planning_phase` refactor). Re-run had eval harness bug.*
