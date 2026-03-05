# Nginx Benchmark Evaluation Report — 4-Way Comparison

**Date:** 2026-03-04
**Benchmark:** nginx/nginx bug-fix tasks (curated from nginx commit history)
**Tasks evaluated:** 5 (C language, 2-10 LOC gold fixes)
**Scoring:** Compile nginx from patched source + `prove` against nginx-tests
**Impl model:** Claude Sonnet | **Planning model:** Claude Opus

## What We Tested

Extended the evaluation harness to support a second benchmark: C-language bug fixes in the nginx web server. This tests the same 4-way comparison (raw/impl/full/nlcmd) against a fundamentally different domain — low-level C systems programming rather than Python library bugs.

### Task Characteristics

Unlike SWE-bench (Python, typically 10-50 LOC fixes), nginx tasks involve:
- **C language** with manual memory management and pointer semantics
- **Small, precise fixes** (2-10 LOC gold patches)
- **Complex module interactions** (HTTP/2 upstream, flow control, buffer chains)
- **No test infrastructure** (tests are in a separate repo, run via Perl `prove`)

### Scoring

Each task is scored by:
1. Compiling nginx from the patched worktree (`./auto/configure` + `make`)
2. Running the relevant test file via `prove` with `TEST_NGINX_BINARY` pointing to the compiled binary
3. Checking specific named TAP assertions (`expected_pass_tests`) rather than overall pass/fail

## Performance Results

### Completion & Test Results

| Metric | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| **Compiled** | 4/5 | **5/5** | **5/5** | 4/5 |
| **Tests passed** | 4/5 | 4/5 | **5/5** | 4/5 |
| Compile failures | 1 | 0 | 0 | 1 |
| Timeouts | 0 | 0 | 0 | 0 |

### Timing & Cost

| Metric | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Total time | 387s (6.4 min) | 899s (15 min) | 8,437s (2.3 hrs) | 10,031s (2.8 hrs) |
| Avg time/task | 97s | 180s | 1,687s (28 min) | 2,508s (42 min) |
| Cost (USD) | $0.71 | ~$4† | ~$112† | $5.07 |
| Avg cost/task | $0.14 | ~$0.83† | ~$22.39† | $1.01 |

*†impl and full costs estimated from single-task JSONL measurement (d7a24947) × 5. Full mode cost is dominated by 4 Opus planning calls ($75/M output, $18.75/M cache_write).*

### Speed Comparison (relative to raw)

| Mode | Speed vs raw |
|------|-------------|
| **impl** | 1.9x slower |
| **full** | 17x slower |
| **nlcmd** | 26x slower |

## Per-Task Results

| # | Task | Gold LOC | raw | impl | full | nlcmd |
|---|------|----------|-----|------|------|-------|
| 1 | SCGI content_length (`ec714d52`) | 6 | PASS | PASS | PASS | PASS |
| 2 | H2 cache+keepalive (`f8e1bc5b`) | 7 | CF | PASS | PASS | CF |
| 3 | H2 reinit buffers (`cd12dc4f`) | 2 | PASS | FAIL | PASS | PASS |
| 4 | Output chain last_buf (`3afd85e4`) | 10 | PASS | PASS | PASS | PASS |
| 5 | Upstream reinit (`d7a24947`) | 6 | PASS | PASS | PASS | PASS |

CF = compile failure

## Patch Quality Analysis

### Task 1: `nginx__ec714d52` — SCGI CONTENT_LENGTH incorrect when unbuffered

**Bug:** With `scgi_request_buffering off`, CONTENT_LENGTH is calculated from buffer sizes instead of the actual Content-Length header.
**Gold fix:** 6 LOC — check `r->request_body_no_buffering` and use `r->headers_in.content_length_n`.

| Aspect | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Patch approach | Correct | Correct | Correct | Correct |
| Patch size | +10/-5 | +10/-5 | +10/-5 | +10/-5 |
| Test result | PASS | PASS | PASS | PASS |

**All modes produced identical, correct patches.** Initially scored as FAIL due to missing Perl `SCGI` module on the test machine. After installing `SCGI` v0.6, all four modes pass.

---

### Task 2: `nginx__f8e1bc5b` — HTTP/2 upstream cache+keepalive stream error

**Bug:** `ctx->id` is set to 1 during connection init even on cache hits (no actual upstream connection), causing spurious "upstream sent frame for unknown stream" errors.
**Gold fix:** 7 LOC — skip `ctx->id` assignment when no connection exists.

| Aspect | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Core fix (stream_id check) | Yes | Yes | Yes | Yes |
| Init-path fix | Replaced `goto done` with inline init | Added `c != NULL` guard | 3 files, +117 lines (over-engineered) | Similar to raw |
| Compiles | **No** | Yes | Yes | **No** |
| Test result | CF | PASS | PASS | CF |

**Divergent approaches to the init path.** All modes correctly added `ctx->id &&` to the stream_id validation check. But the second fix (preventing `ctx->id = 1` on cache hits) varied:
- **raw/nlcmd:** Replaced `goto done` with inline window initialization and `return NGX_OK`, but left the `done:` label orphaned with no remaining `goto done`. nginx compiles with `-Wall -Werror`, so the `-Wunused-label` warning becomes a fatal error.
- **impl:** Added a `c != NULL` guard around the `ctx->id = 1` assignment — minimal, conservative, and preserves the existing `goto done` control flow. Compiles cleanly.
- **full:** Used a different semantic approach (`ctx->header_sent` flag) to avoid the init-path issue entirely. More lines but compiles and passes.

---

### Task 3: `nginx__cd12dc4f` — HTTP/2 upstream buffers not cleared on retry

**Bug:** `ctx->in` and `ctx->busy` not cleared in `reinit_request`, causing corrupted DATA frames on upstream retry.
**Gold fix:** 2 LOC — add `ctx->in = NULL; ctx->busy = NULL;` in `ngx_http_proxy_v2_reinit_request()`.

| Aspect | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Fixed proxy_v2_module | Yes | **No** | Yes | Yes |
| Fixed grpc_module (bonus) | Yes | Yes | Yes | Yes |
| Patch size | +4 (2 files) | +3 (1 file) | +22 (2 files) | +8 (2 files) |
| Test result | PASS | **FAIL** | PASS | PASS |

**impl patched the wrong module.** The gold fix targets `ngx_http_proxy_v2_module.c`, and the test exercises the proxy_v2 code path. The problem statement says "HTTP/2 upstream" without naming files. impl's single-pass FSM found `ngx_http_grpc_reinit_request()` first (alphabetically earlier) and stopped. The fix is correct for gRPC but misses the proxy_v2 module that the test actually exercises. All other modes (which search more broadly or have planning) correctly patched both modules.

---

### Task 4: `nginx__3afd85e4` — Stale last_buf flag causes premature END_STREAM

**Bug:** Reused destination buffer keeps `last_buf = 1` from previous use, causing premature END_STREAM on retry.
**Gold fix:** 10 LOC — clear `flush`, `last_buf`, `last_in_chain` in the else branch.

| Aspect | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Core fix correct | Yes | Yes | Yes | Yes |
| Patch size | +10 | +10 | +8 | +5 |
| Approach | Identical to gold | Identical to gold | Slightly different structure | More minimal |
| Test result | PASS | PASS | PASS | PASS |

**All modes correct.** raw and impl produced patches identical to the gold fix. full and nlcmd used slightly different but equivalent approaches with fewer lines.

---

### Task 5: `nginx__d7a24947` — Upstream reinit not called on early response

**Bug:** `ngx_http_upstream_reinit()` only called when `u->request_sent` is true, but response can arrive before request is fully sent.
**Gold fix:** 6 LOC — change condition to `u->request_sent || u->buffer.start != NULL`.

| Aspect | raw | impl | full | nlcmd |
|--------|-----|------|------|-------|
| Core fix correct | Yes | Yes | Yes | Yes |
| Patch size | +1/-1 | +1/-1 | +2/-1 | +1/-1 |
| Test result | PASS | PASS | PASS | PASS |

**All modes produced the correct one-line fix.** The condition change is identical across all modes.

## Aggregate Quality

| Quality Dimension | raw | impl | full | nlcmd |
|-------------------|-----|------|------|-------|
| Correct patches | 4/5 (80%) | 4/5 (80%) | 5/5 (100%) | 4/5 (80%) |
| Compiles successfully | 4/5 (80%) | 5/5 (100%) | 5/5 (100%) | 4/5 (80%) |
| Tests pass | 4/5 (80%) | 4/5 (80%) | **5/5 (100%)** | 4/5 (80%) |
| Minimal patches | 4/5 | 4/5 | 2/5 | 4/5 |

Notes:
- ec714d52 now passes all modes after installing Perl SCGI module
- raw/nlcmd fail f8e1bc5b due to compile issues in their init-path approach
- impl fails cd12dc4f due to incomplete fix (one module instead of two)
- full tends to produce larger patches (+117 lines for f8e1bc5b) but they compile and pass

## Key Findings

### 1. Full mode achieves 100% test pass rate

Full mode (5/5) outperforms all others (4/5 each). The planning pipeline helps the model consider all affected code paths — particularly visible in cd12dc4f where full correctly patched both modules while impl missed one.

### 2. C code is harder than Python

Compared to SWE-bench (Python), where impl/full/nlcmd all achieved 100% correctness on 5 tasks, the nginx benchmark shows more failures across all modes. C-language bugs involving pointer management, buffer chains, and multi-module interactions are fundamentally harder for the model.

### 3. `-Werror` is a C-specific failure mode the model doesn't anticipate

Both raw and nlcmd failed to compile f8e1bc5b because they orphaned a `done:` label (removed `goto done` but left `done:`). nginx compiles with `-Wall -Werror`, promoting `-Wunused-label` from warning to fatal error. The model produced logically correct code that a lenient compiler would accept — it doesn't model the project's specific compiler flags. impl avoided this by taking a more conservative approach that preserved the existing control flow.

### 4. Incomplete search is a single-pass failure mode

impl's cd12dc4f failure stems from finding the first `reinit_request` match (`ngx_http_grpc_module.c`) and stopping, missing the second in `ngx_http_proxy_v2_module.c`. Planning modes (raw/full/nlcmd) search more broadly and find both. This suggests single-pass FSM execution without planning is vulnerable to "first match" bias in multi-module bugs.

### 5. SCGI test infra gap resolved

Task 1 (ec714d52) initially failed universally due to missing Perl `SCGI` module. After installing SCGI v0.6, all four modes pass — confirming the identical, correct patches all modes produced.

## Appendix: Tasks Evaluated

| # | Instance ID | Bug Description | Gold LOC | Files Changed |
|---|-------------|-----------------|----------|---------------|
| 1 | `nginx__ec714d52` | SCGI CONTENT_LENGTH wrong with unbuffered mode | 6 | `ngx_http_scgi_module.c` |
| 2 | `nginx__f8e1bc5b` | HTTP/2 cache+keepalive stream ID error | 7 | `ngx_http_proxy_v2_module.c` |
| 3 | `nginx__cd12dc4f` | HTTP/2 upstream buffers not cleared on retry | 2 | `ngx_http_proxy_v2_module.c` |
| 4 | `nginx__3afd85e4` | Stale last_buf flag causes premature END_STREAM | 10 | `ngx_output_chain.c` |
| 5 | `nginx__d7a24947` | Upstream reinit not called on early response | 6 | `ngx_http_upstream.c` |
