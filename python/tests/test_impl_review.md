# test_impl_review.py

Unit tests for the review-stage gate in the `impl` workflow.

## Purpose

Validate deterministic review gating behavior that consumes model review output,
produces structured artifacts, and drives retry decisions.

## Coverage

- Structured review JSON parsing and threshold gate evaluation.
- Threshold policy enforcement for `faithful/style/docs/corner_cases` scores.
- Fallback parsing behavior for non-JSON review output text.
- Deterministic `.tmp/review-iter-{N}.json` artifact generation.
- Pipeline failure handling with non-blocking diagnostics artifact output.

## Design Rationale

The tests prioritize objective workflow contracts: score normalization,
threshold decisions, and artifact emissions. This keeps review-stage behavior
stable even when prompt text or model-specific output style evolves.
