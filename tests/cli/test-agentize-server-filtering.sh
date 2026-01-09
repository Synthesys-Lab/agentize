#!/usr/bin/env bash
# Test: server filter_ready_issues returns expected issues and debug logs

source "$(dirname "$0")/../common.sh"

test_info "server filter_ready_issues filtering and debug logs"

# Test data: mix of ready, wrong-status, and missing-label issues
TEST_ITEMS='[
  {"content": {"number": 42, "labels": {"nodes": [{"name": "agentize:plan"}, {"name": "bug"}]}}, "fieldValueByName": {"name": "Plan Accepted"}},
  {"content": {"number": 43, "labels": {"nodes": [{"name": "enhancement"}]}}, "fieldValueByName": {"name": "Backlog"}},
  {"content": {"number": 44, "labels": {"nodes": [{"name": "feature"}]}}, "fieldValueByName": {"name": "Plan Accepted"}},
  {"content": null, "fieldValueByName": null}
]'

# Test 1: filter_ready_issues returns expected ready issues
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import json
from agentize.server.__main__ import filter_ready_issues

items = json.loads('''$TEST_ITEMS''')
ready = filter_ready_issues(items)
print(' '.join(map(str, ready)))
")

if [ "$output" != "42" ]; then
  test_fail "Expected ready issues [42], got [$output]"
fi

# Test 2: debug log output contains [issue-filter] prefix and reason tokens
debug_output=$(PYTHONPATH="$PROJECT_ROOT/python" HANDSOFF_DEBUG=1 python3 -c "
import json
from agentize.server.__main__ import filter_ready_issues

items = json.loads('''$TEST_ITEMS''')
filter_ready_issues(items)
" 2>&1)

if ! echo "$debug_output" | grep -q '\[issue-filter\]'; then
  test_fail "Debug output missing [issue-filter] prefix"
fi

if ! echo "$debug_output" | grep -q 'READY'; then
  test_fail "Debug output missing READY token"
fi

if ! echo "$debug_output" | grep -q 'SKIP'; then
  test_fail "Debug output missing SKIP token"
fi

if ! echo "$debug_output" | grep -q 'Summary:'; then
  test_fail "Debug output missing Summary line"
fi

# Test 3: debug logging does not alter the returned list
debug_result=$(PYTHONPATH="$PROJECT_ROOT/python" HANDSOFF_DEBUG=1 python3 -c "
import json
from agentize.server.__main__ import filter_ready_issues

items = json.loads('''$TEST_ITEMS''')
ready = filter_ready_issues(items)
print(' '.join(map(str, ready)))
" 2>/dev/null)

if [ "$debug_result" != "42" ]; then
  test_fail "Debug mode altered result: expected [42], got [$debug_result]"
fi

test_pass "server filter_ready_issues filtering and debug logs work correctly"
