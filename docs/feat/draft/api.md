# Workflow API and Plan Pipeline Example

Define a lightweight, imperative workflow API for coordinating agent sessions, with the plan pipeline as the canonical example.

## Goals

- Provide an **imperative** workflow style that matches real pipelines (including loops).
- Centralize **artifact management, retry, concurrency, and error handling** in a shared API.
- Make **plan** and **impl** pipelines small example workflows that call the API directly.
- Rename `workflow/utils/` to `workflow/api/` to reflect a public, user-facing interface.

## Non-Goals

- Full DAG scheduling, advanced dependency graphs, or complex orchestration engines.
- Hiding all exceptions; failures should be surfaced to the caller.
- Long-term compatibility with old import paths.

## Requirements

### API Surface

- `workflow/api/session.py` provides `Session` as the primary imperative interface.
- `Session.run_prompt(...)` runs a single agent session with:
  - input/output artifact naming
  - output validation
  - retry with configurable attempts
  - consistent errors
  - optional input/output path overrides for workflows that reuse fixed artifacts
- `Session.run_parallel(...)` runs multiple sessions concurrently with the **same retry policy**.
- `Session.stage(...)` builds a lightweight call object for `run_parallel(...)`.
- `StageResult` exposes `stage`, `input_path`, `output_path`, and `process` with a `.text()` helper.
- `PipelineError` (or equivalent) carries `stage`, `attempts`, and `last_error`.

### Behavior

- **Retry semantics**: `retry=N` means up to `1 + N` attempts, stopping on first success.
- **Failure conditions**:
  - non-zero process return code
  - missing output file
  - empty output file
- **Concurrency model**: minimal scheduling sufficient for parallel ACW sessions (e.g., two-way fan-out).

### Example Workflow

- The plan pipeline must be implemented using the API and documented as the **primary example**.
- The plan pipeline is **imperative**, not declarative/staged.
- Issue creation returns an issue number used as the output prefix.

## Proposed Structure

```
python/agentize/workflow/api/
  README.md
  __init__.py
  __init__.md
  acw.py
  acw.md
  gh.py
  gh.md
  path.py
  path.md
  prompt.py
  prompt.md
  session.py
  session.md
```

`workflow/utils/` is renamed to `workflow/api/`. Existing modules move with their `.md` companions to preserve documentation completeness.

## API Design (Imperative)

### Session

- **Constructor**: `Session(output_dir, prefix, *, runner=run_acw, input_suffix="-input.md", output_suffix="-output.md")`
- **run_prompt**:
  - `run_prompt(name, prompt, backend, *, tools=None, permission_mode=None, timeout=3600, extra_flags=None, retry=0, retry_delay=0, input_path=None, output_path=None) -> StageResult`
  - Writes input file, runs ACW, validates output, retries on failure.
- **stage**:
  - `stage(name, prompt, backend, **opts) -> StageCall`
  - A small value object used by `run_parallel`.
- **run_parallel**:
  - `run_parallel(calls, *, max_workers=2, retry=0, retry_delay=0) -> dict[str, StageResult]`
  - Executes calls concurrently and validates each result.

### StageResult

- Fields: `stage`, `input_path`, `output_path`, `process`
- Helper: `.text()` to return output as string

### Error Handling

- `PipelineError` raised from the API; callers do not wrap errors by default.
- Error includes `stage`, `attempts`, and `last_error` to aid debugging.

## Plan Pipeline as Example

The plan pipeline is written **imperatively** and uses `Session` as its only execution primitive:

```python
from agentize.workflow.api.session import Session
from agentize.workflow.api import gh

def pipeline(user_prompt: str):
    issue = gh.create_issue(title="...", body=user_prompt)

    sess = Session(output_dir=".tmp", prefix=f"issue-{issue.number}")

    understander = sess.run_prompt(
        "understander",
        render_prompt("path/to/understander.md", {"feat": user_prompt}),
        backend=("claude", "opus"),
    )

    bold = sess.run_prompt(
        "bold",
        render_prompt("path/to/understand.md", {"feat": user_prompt, "understander": understander.text()}),
        backend=("claude", "opus"),
        retry=5,
    )

    parallel = sess.run_parallel(
        [
            sess.stage("critique", render_critique(bold.text()), backend=("claude", "opus")),
            sess.stage("reducer", render_reducer(bold.text()), backend=("claude", "opus")),
        ],
        retry=5,
    )

    consensus = sess.run_prompt(
        "consensus",
        render_consensus(parallel["critique"].text(), parallel["reducer"].text()),
        backend=("claude", "opus"),
        retry=5,
    )

    gh.edit_issue(body=consensus.text(), title="...")
```

This example is the canonical reference for users to build their own workflows.

## Rationale and Trade-offs

- **Imperative flow** aligns with loop-based workflows and is easier to read for iterative pipelines.
- **API-owned error handling** ensures consistent validation and avoids duplicated checks.
- **Minimal concurrency** reduces surface area while covering the main use case (parallel ACW sessions).
- Trade-off: declarative DAGs are less ergonomic here, but can be added later if needed.

## Migration Plan

1. **Rename and move modules**
   - Move `workflow/utils/` → `workflow/api/`
   - Update all imports in code and tests
2. **Introduce `api/session.py`**
   - Implement `Session`, `StageResult`, `StageCall`, `PipelineError`
   - Add `.md` companion documentation for `session.py`
3. **Refactor planner into example pipeline**
   - Keep CLI in `planner/__main__.py`
   - Move workflow logic into a small `planner/pipeline.py` (or equivalent)
   - Ensure plan pipeline example is documented and stays minimal
4. **Refactor impl pipeline**
   - Replace internal runner logic with `Session`
   - Preserve loop-style logic
5. **Update docs and tests**
   - Update `workflow/api/README.md` to explain the public API
   - Update tests and documentation references to `workflow/api`

## New Code to Implement

- `python/agentize/workflow/api/session.py`
- `python/agentize/workflow/api/session.md`
- `python/agentize/workflow/api/README.md` updates to include `Session`
- `python/agentize/workflow/planner/pipeline.py` (example workflow entry)
- `python/agentize/workflow/planner/pipeline.md`
- `python/agentize/workflow/impl/pipeline.py` (if `impl` becomes an example)
- `python/agentize/workflow/impl/pipeline.md`
- Import updates across code and tests to replace `workflow.utils` with `workflow.api`
