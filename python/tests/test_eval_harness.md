# test_eval_harness.py

Tests for `agentize.eval.eval_harness` pure functions.

## Scope

- `_compute_cost`: Cache-tier-aware pricing with `cache_read` and `cache_write` parameters
- `_parse_claude_usage`: Cache token extraction from `claude -p` JSON output
- `_sum_jsonl_usage`: Deduplication by `message.id` to avoid counting streamed content blocks
- `aggregate_metrics`: Cost + per-phase timing aggregation across task results
- `run_nlcmd_impl`: Planning-timeout status handling
- `_make_result`: Default timing fields (`planning_time`, `impl_time`)
- `extract_patch`: Git diff extraction from worktrees
- `write_overrides`: Shell override generation for eval isolation

## Test Data

Tests use inline JSON strings and `tmp_path` fixtures for JSONL files with:
- Duplicate `message.id` entries (simulating streaming content blocks)
- Cache token fields (`cache_read_input_tokens`, `cache_creation_input_tokens`)
- Mixed entries with and without `message.id`
