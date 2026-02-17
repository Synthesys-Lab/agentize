# test-lol-plan-backend-flags.sh

Validates backend flag handling for `lol plan`.

## Test Cases

### backend_override_forwarded
Purpose: Ensure `--backend` is accepted and forwarded to the planner pipeline.

Setup: Stub `_planner_run_pipeline`, then run `lol plan --dry-run --backend codex:gpt-5.2-codex`.

Expected: Exit code 0 and captured pipeline arguments include `codex:gpt-5.2-codex`.

### stage_specific_flags_rejected
Purpose: Ensure stage-specific backend flags remain unsupported for `lol plan`.

Setup: Run `lol plan --dry-run --understander cursor:gpt-5.2-codex`.

Expected: Non-zero exit and error output references `.agentize.local.yaml`.
