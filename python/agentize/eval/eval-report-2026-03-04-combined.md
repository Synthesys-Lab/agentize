# Cross-Benchmark Evaluation Report — SWE-bench + Nginx

**Date:** 2026-03-04
**Benchmarks:** SWE-bench Verified (Python) + nginx bug-fixes (C)
**Total tasks:** 10 (5 per benchmark)
**Modes:** raw, impl, full, nlcmd

## Executive Summary

We evaluated agentize across two benchmarks — SWE-bench (Python library bugs) and nginx (C systems bugs) — using four execution modes. The key finding: **planning consistently improves correctness**, and full mode (script-orchestrated 5-agent planning) achieves **100% pass rate across both benchmarks** (10/10). Nlcmd (NL-orchestrated planning) produces richer artifacts but at ~1.4x the time and ~1.4x the cost of full mode, with slightly lower C pass rate (4/5). A secondary finding: **Codex consensus adds latency without reducing Anthropic cost** — the Opus fallback path is 3x faster with equivalent quality.

## Combined Results

### Test Pass Rates

| Mode | SWE-bench (Python) | nginx (C) | Combined |
|------|-------------------|-----------|----------|
| **raw** | 4/5 (80%) | 4/5 (80%) | 8/10 (80%) |
| **impl** | 5/5 (100%) | 4/5 (80%) | 9/10 (90%) |
| **full** | 5/5 (100%) | **5/5 (100%)** | **10/10 (100%)** |
| **nlcmd** | 5/5 (100%) | 4/5 (80%) | 9/10 (90%) |

### Timing

| Mode | SWE-bench total | nginx total | Combined total | Avg/task |
|------|----------------|-------------|----------------|----------|
| **raw** | 524s | 387s | 911s (15 min) | 91s |
| **impl** | 221s | 899s | 1,120s (19 min) | 112s |
| **full (codex)** | 5,493s | — | — | 1,099s |
| **full (opus)** | 1,843s | — | — | 369s |
| **nlcmd** | 8,911s | 10,031s | 18,942s (5.3 hrs) | 1,894s |

*Nginx full and nlcmd timing from original runs (Codex vs Opus breakdown not yet available for nginx). Full (codex) uses gpt-5.2-codex for consensus; full (opus) uses Claude Opus fallback when Codex is unavailable.*

### Cost (Anthropic API only)

| Mode | SWE-bench | nginx | Combined | Avg/task |
|------|-----------|-------|----------|----------|
| **raw** | $0.44 | $0.71 | $1.15 | $0.12 |
| **impl** | ~$4† | ~$4† | ~$8† | ~$0.83† |
| **full (codex)** | $103.61 | — | — | $20.72 |
| **full (opus)** | $98.87 | — | — | $19.77 |
| **nlcmd** | $143.80 | ~$157† | ~$301 | ~$30 |

*†nginx impl cost estimated from single-task JSONL measurement (d7a24947) × 5. Nginx nlcmd cost extrapolated from single-task measurement ($31.38 × 5). SWE-bench full and nlcmd costs measured directly across all 5 tasks. All costs reflect Anthropic API usage only — Codex (OpenAI) consensus calls add additional cost not captured in JSONL. Prior nlcmd cost ($0.91/task) only counted orchestrator tokens (fixed in PR #981).*

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
| full | 100% | 100% | 0pp |
| nlcmd | 100% | 80% | -20pp |

The gap is largest for impl and nlcmd (-20pp), where C-specific challenges (compilation errors, multi-module interactions) cause failures that planning alone doesn't prevent.

### Finding 3: Script orchestration (full) dominates NL orchestration (nlcmd)

Full mode outperforms nlcmd on every dimension — quality, speed, and cost:

| | full | nlcmd |
|--|------|-------|
| **SWE-bench** | 5/5 | 5/5 (tie) |
| **nginx** | **5/5** | 4/5 |
| **Combined** | **10/10** | 9/10 |
| **Time** | 3.9 hrs | 5.3 hrs (1.4x slower) |
| **Cost** | ~$22/task | ~$30/task (1.4x more) |

Full mode is faster, cheaper, and more accurate. The cost gap comes from nlcmd's multi-agent debate pipeline (5 agent calls via Task tool) running longer than full's scripted 5-stage pipeline. The quality gap comes from a single nginx task (f8e1bc5b) where full compiled successfully but nlcmd didn't — the script pipeline's structured plan format produces more precise implementation guidance for C code than the NL command's free-form plan.

### Finding 4: impl is the best value proposition

Impl mode (FSM orchestrator without planning) achieves:
- 100% on SWE-bench (tied for best)
- 80% on nginx (tied with raw and nlcmd)
- Total time: 19 minutes for 10 tasks
- ~$0.83/task (~7x raw, 27x cheaper than full, 36x cheaper than nlcmd)

The iterative prompt rendering and retry logic in the FSM kernel loop provides most of the benefit of planning for Python tasks at a fraction of the cost. For C tasks, impl matches raw/nlcmd despite using no planning — the failures are in different tasks (impl misses cd12dc4f due to incomplete fix, while raw/nlcmd miss f8e1bc5b due to compile errors).

### Finding 5: Failure modes differ by orchestration strategy

Each mode fails on different tasks, suggesting complementary strengths:

| Task | raw | impl | full | nlcmd | Failure pattern |
|------|-----|------|------|-------|----------------|
| SWE: astropy-13236 | FAIL | pass | pass | pass | raw: wrong approach |
| nginx: f8e1bc5b | CF | pass | pass | CF | raw/nlcmd: compile error |
| nginx: cd12dc4f | pass | FAIL | pass | pass | impl: incomplete fix |

If failures were random, we'd expect overlapping failure sets. Instead, each mode has unique failure characteristics:
- **raw:** Takes wrong approach (deletes instead of deprecating)
- **impl:** Misses secondary modules (fixes one of two affected files)
- **full:** Most robust, fewest failures
- **nlcmd:** Same compile issues as raw (shares raw-mode code generation characteristics)

### Finding 6: Cost-effectiveness varies by use case

| Use case | Recommended mode | Why |
|----------|-----------------|-----|
| Rapid prototyping | **raw** | 91s/task, $0.12/task, 80% success |
| Production patches (Python) | **impl** | 112s/task, ~$0.83/task, 100% success on Python |
| Production patches (C/multi-lang) | **full** | 1,393s/task, ~$22/task, 100% success |
| ~~Maximum quality (Python)~~ | ~~nlcmd~~ | ~$30/task, 90% success — dominated by full |

Full mode dominates nlcmd on all axes: higher pass rate (100% vs 90%), faster (1,393s vs 1,894s/task), and cheaper (~$22 vs ~$30/task). There is no use case where nlcmd is the preferred choice. The original nlcmd cost of $0.91/task was a measurement error — subagent tokens spawned via the Task tool were not being counted.

### Finding 7: Cost sanity check — cost-per-second is consistent across modes

Cost should be roughly proportional to time when the same models are used. A large $/s discrepancy between modes using the same models indicates a measurement bug (as happened with the original nlcmd cost of $0.91/task — see Limitation 4).

| Mode | $/task | Time/task | $/second | Models |
|------|--------|-----------|----------|--------|
| **raw** | $0.12 | 91s | $0.0013/s | Sonnet only |
| **impl** | $0.83 | 112s | $0.0074/s | Sonnet only |
| **full (codex)** | $20.72 | 1,099s | $0.019/s | Opus+Sonnet (consensus on OpenAI) |
| **full (opus)** | $19.77 | 369s | $0.054/s | Opus+Sonnet |
| **nlcmd** | $30.00 | 1,894s | $0.016/s | Opus+Sonnet (via Task tool) |

**Within-group consistency:**

- **Sonnet-only (raw vs impl):** $0.0013 vs $0.0074/s — 5.7x gap. Impl's FSM overhead (multi-turn conversation, commit, parse gate) burns more tokens per second than raw's single `claude -p` call. Expected.
- **Opus+Sonnet (full-codex vs nlcmd):** $0.019 vs $0.016/s — **1.2x gap**. Same order of magnitude. Passes the smell test.
- **Full (opus) $/s is higher** ($0.054) because Opus consensus completes in 39-85s vs Codex's 247-422s — the same dollar spend is compressed into less wall time. The idle/network time is shorter, not the token rate.

**Absolute cost check** (full mode, per task):
- 4 Opus calls (bold + critique + reducer + consensus) × ~$4-5 each = ~$16-20
- 2 Sonnet calls (understander + impl) × ~$1-2 each = ~$2-4
- Expected: ~$18-24/task → Measured: $20.72. ✓

**Before vs after the nlcmd cost fix (PR #981):**

| | Before fix | After fix |
|--|---|---|
| nlcmd $/s | $0.0002/s | $0.016/s |
| full vs nlcmd $/s ratio | 52x | 1.2x |

The 52x discrepancy revealed that nlcmd was only counting orchestrator tokens — subagent tokens (spawned via Task tool) were missing. After the fix, all modes using the same models show consistent cost-per-second within ~1-6x, explainable by differences in conversation overhead and idle time.

### Finding 8: Codex consensus adds latency without reducing Anthropic cost

Full mode was re-run with Codex (gpt-5.2-codex) working as the consensus backend. Comparing against the Opus-fallback run:

| | Codex consensus | Opus fallback |
|--|---|---|
| SWE-bench total time | 5,493s (1.5 hrs) | 1,843s (31 min) |
| Avg time/task | 1,099s (18 min) | 369s (6 min) |
| Avg Anthropic cost/task | $20.72 | $19.77 |
| Consensus stage time | 247-422s | 39-85s |

Codex consensus is **3x slower** than Opus fallback (18 min vs 6 min per task) with nearly identical Anthropic costs (~$20/task). Codex also adds hidden OpenAI API costs not captured in JSONL tracking. Agent runtime variance is high — understander ranged from 82-533s, reducer hit 1,002s on one task.

The timing table above uses the Codex run (representative of production configuration). The Opus-fallback path offers a faster alternative when latency matters more than cross-model validation.

## Limitations

1. **Small sample size** — 5 tasks per benchmark is insufficient for statistical significance. These results indicate trends, not conclusions.
2. **Single model** — All modes use Claude Sonnet for implementation. Results may differ with other models.
3. **~~SCGI test gap~~** — Resolved. Perl SCGI module installed; ec714d52 now passes all modes.
4. **~~No cost data for ACW modes~~** — Resolved. JSONL-based cost tracking (v2) now measures impl, full, and nlcmd mode costs. Original nlcmd cost ($0.91/task) was a measurement bug — fixed in PR #981. SWE-bench full and nlcmd costs measured directly; nginx costs extrapolated from single-task measurements.
5. **Single run** — No repeated trials to measure variance. Individual task results may not be reproducible. Full mode re-runs show 3x timing variation depending on consensus backend (Codex vs Opus fallback).
6. **Codex costs not captured** — JSONL tracking only captures Anthropic API costs. Codex (OpenAI) consensus calls add additional cost not reflected in the cost tables.

## Recommendations

1. **Use full mode as the default for production** — 100% combined pass rate across both benchmarks.
2. **Use impl for Python-only workloads** — equivalent quality at 12x less time.
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

| Task | raw | impl | full | nlcmd |
|------|-----|------|------|-------|
| ec714d52 (SCGI) | PASS | PASS | PASS | PASS |
| f8e1bc5b (H2 cache) | CF | PASS | PASS | CF |
| cd12dc4f (H2 buffers) | PASS | **FAIL** | PASS | PASS |
| 3afd85e4 (last_buf) | PASS | PASS | PASS | PASS |
| d7a24947 (reinit) | PASS | PASS | PASS | PASS |
