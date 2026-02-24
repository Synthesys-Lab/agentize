#!/usr/bin/env bash
# Test: eval harness CLI invocation and --dry-run mode
# Validates that the eval harness module is importable and CLI parses args

source "$(dirname "$0")/../common.sh"

test_info "eval harness CLI invocation"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"

# Test 1: Module is importable
python -c "from agentize.eval.eval_harness import main" || test_fail "eval_harness module not importable"

# Test 2: No subcommand prints help and exits non-zero
output=$(python -m agentize.eval.eval_harness 2>&1) || true
echo "$output" | grep -q "usage:" || echo "$output" | grep -q "SWE-bench" || test_fail "no-command output missing usage info"

# Test 3: run --help exits cleanly
python -m agentize.eval.eval_harness run --help >/dev/null 2>&1 || test_fail "run --help failed"

# Test 4: score --help exits cleanly
python -m agentize.eval.eval_harness score --help >/dev/null 2>&1 || test_fail "score --help failed"

# Test 5: aggregate_metrics produces correct JSON structure
output=$(python -c "
import json
from agentize.eval.eval_harness import aggregate_metrics
results = [
    {'instance_id': 'a', 'status': 'completed', 'tokens': 100, 'wall_time': 10.0},
    {'instance_id': 'b', 'status': 'timeout', 'tokens': 0, 'wall_time': 1800.0},
]
m = aggregate_metrics(results)
print(json.dumps(m))
")
echo "$output" | python -c "
import sys, json
m = json.load(sys.stdin)
assert m['total_tasks'] == 2, f'total_tasks={m[\"total_tasks\"]}'
assert m['completed'] == 1, f'completed={m[\"completed\"]}'
assert m['timeouts'] == 1, f'timeouts={m[\"timeouts\"]}'
" || test_fail "aggregate_metrics produced wrong structure"

# Test 6: write_overrides creates valid bash script
TMP_DIR=$(make_temp_dir "test-eval-harness-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

python -c "
from agentize.eval.eval_harness import write_overrides
path = write_overrides('$TMP_DIR', 'test-instance-1')
print(path)
" > "$TMP_DIR/overrides-path.txt" || test_fail "write_overrides failed"

OVERRIDES_PATH=$(cat "$TMP_DIR/overrides-path.txt")
[ -f "$OVERRIDES_PATH" ] || test_fail "overrides file not created"
bash -n "$OVERRIDES_PATH" || test_fail "overrides file has syntax errors"

test_pass "eval harness CLI tests"
