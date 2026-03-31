# test-eval-harness-cli.sh

Validates that the evaluation harness CLI remains callable from the repo test
environment and exposes the benchmark and backend-selection flags needed for
SWE-bench runs.

## What it checks

- The Python module imports with the repo-local `PYTHONPATH`.
- `run` and `score` help output parse successfully.
- Aggregate metrics keep the expected JSON shape.
- The generated override script is syntactically valid.
- The `run --help` output advertises benchmark selection plus planner and impl
  backend overrides.
- nginx task loading still works for the secondary benchmark path.

## Why this matters

The eval harness is used as an operator-facing entrypoint rather than only as a
library. A lightweight CLI test catches missing flags or import regressions
before long-running benchmark jobs fail after setup.
