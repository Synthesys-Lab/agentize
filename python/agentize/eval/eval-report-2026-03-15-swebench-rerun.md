# SWE-bench Rerun Evaluation Report

**Date:** 2026-03-15
**Benchmark:** SWE-bench Verified (5 astropy tasks)
**Modes:** raw, impl, full (codex fallback), full (opus)

## Executive Summary

We re-evaluated agentize on SWE-bench Verified with updated cost tracking and an additional mode variant (full with Opus planning model). The key finding: **planning doubles the resolve rate from 20% to 40%**, but all three planning modes (impl, full-codex, full-opus) achieve the same 40% — the planning mode and model choice don't matter for this task set. Impl mode is the clear winner on cost-effectiveness at **$2.15 total vs $63 for full modes**, achieving identical results.

## Results

### Resolve Rates

| Mode | Resolved | Rate | Cost | Cost/task |
|------|----------|------|------|-----------|
| **raw** | 1/5 | 20% | $0.15 | $0.03 |
| **impl** | 2/5 | 40% | $2.15 | $0.43 |
| **full (codex)** | 2/5 | 40% | $63.24 | $12.65 |
| **full (opus)** | 2/5 | 40% | $62.69 | $12.54 |

### Per-Instance Results

| Instance | raw | impl | full-codex | full-opus |
|----------|-----|------|------------|-----------|
| astropy-12907 | **PASS** | **PASS** | **PASS** | **PASS** |
| astropy-13033 | FAIL | FAIL | FAIL | FAIL |
| astropy-13236 | FAIL | FAIL | FAIL | FAIL |
| astropy-13398 | FAIL | FAIL | FAIL | FAIL |
| astropy-13453 | FAIL | **PASS** | **PASS** | **PASS** |

### Token Usage

| Mode | Total | Mean | Median |
|------|-------|------|--------|
| **raw** | 10,261 | 2,052 | 2,347 |
| **impl** | 20,406 | 4,081 | 2,856 |
| **full (codex)** | 89,941 | 17,988 | 16,634 |
| **full (opus)** | 91,015 | 18,203 | 15,325 |

### Timing

| Mode | Total | Mean |
|------|-------|------|
| **raw** | 328s (5.5 min) | 65.7s |
| **impl** | 1,121s (18.7 min) | 224.2s |
| **full (codex)** | 2,179s (36.3 min) | 435.8s |
| **full (opus)** | 2,660s (44.3 min) | 532.1s |

## Analysis

### Finding 1: Planning helps, but mode/model choice doesn't matter (on this set)

All three planning modes resolve the same two instances (astropy-12907, astropy-13453) while failing the same three. This suggests the planning benefit is binary — it either provides enough context for the FSM to succeed, or the task is beyond what any amount of planning can address. The 3 failing tasks may require deeper architectural understanding or multi-step reasoning that the current pipeline doesn't provide.

### Finding 2: Impl is 29x cheaper than full with identical results

| | impl | full (codex) | Ratio |
|--|------|-------------|-------|
| **Resolve rate** | 40% | 40% | 1.0x |
| **Cost** | $2.15 | $63.24 | **29x cheaper** |
| **Time** | 18.7 min | 36.3 min | **1.9x faster** |
| **Tokens** | 20,406 | 89,941 | **4.4x fewer** |

The 5-agent debate pipeline (understander, bold, critique, reducer, consensus) in full mode consumes ~70k additional tokens per run with zero improvement in resolve rate on this task set.

### Finding 3: First true resolve-rate measurement

The 2026-03-04 evaluation reported **completion rates** (did the pipeline finish and tests pass locally), not **SWE-bench resolve rates** (did the patch fix the issue when scored in the Docker evaluator). This is the first evaluation using SWE-bench's official Docker-based scoring, which applies patches to clean environments and runs the full test suite. The 40% resolve rate for planning modes is our baseline — there is no prior resolve-rate data to compare against.

### Finding 4: Codex fallback adds no value for SWE-bench

Full-codex and full-opus produce nearly identical results:
- Same 2/5 resolve rate
- Similar cost ($63.24 vs $62.69)
- Similar token usage (~90k)
- Full-opus is slightly slower (532s vs 436s mean)

The Codex fallback mechanism (used when gpt-5.2-codex is unavailable for consensus) doesn't impact final outcomes.

## Limitations

1. **Small sample size** — 5 tasks is insufficient for statistical significance. The 60pp regression from Mar 4 may simply reflect task difficulty variance.
2. **Same task set across modes** — All modes see the same 5 instances. A failure-resistant task (astropy-12907) passes everywhere; hard tasks fail everywhere.
3. **No repeated trials** — Single run per mode. Results may not be reproducible.
4. **SWE-bench scoring environment** — Podman compatibility issues required patching the SWE-bench Docker utilities (UID mapping in `copy_to_container`). One instance (astropy-13453) initially errored due to stale container images and required re-scoring.

## Recommendations

1. **Use impl as default** — identical resolve rate to full at 29x less cost.
2. **Scale to 20+ tasks** — 5 tasks cannot distinguish between modes or detect regressions reliably. The 20-task runs are now in progress.
3. **Investigate the 3 failing tasks** — astropy-13033, 13236, and 13398 fail across all modes. Root-cause analysis may reveal pipeline gaps (e.g., multi-file changes, test generation, API migration patterns).
4. **Reconsider full mode cost** — at $12.54/task with no improvement over impl ($0.43/task), the 5-agent debate is not justified for SWE-bench Python tasks.
5. **Add `--resume` to all runs** — now implemented in the harness to handle crashes and podman scoring errors gracefully.
