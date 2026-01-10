#!/usr/bin/env bash
# Test: server filter_ready_issues returns expected issues and debug logs
# Also tests label-first discovery and per-issue status lookup behavior

source "$(dirname "$0")/../common.sh"

test_info "server filter_ready_issues filtering and debug logs"

# Test data: mix of ready, wrong-status, and missing-label issues
# Note: items format includes status field for filter_ready_issues testing
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

# Test 4: get_repo_owner_name returns correct values (unit test)
repo_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import get_repo_owner_name

try:
    owner, repo = get_repo_owner_name()
    print(f'{owner}/{repo}')
except Exception as e:
    print(f'ERROR: {e}')
")

# Verify format is owner/repo (not empty, contains slash)
if ! echo "$repo_output" | grep -q '/'; then
  test_fail "get_repo_owner_name should return owner/repo format, got: $repo_output"
fi

# Test 5: discover_candidate_issues returns list of ints (mocked subprocess)
# This test validates the function can parse gh issue list output correctly
discovery_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
import sys
from unittest.mock import patch, MagicMock

# Mock gh issue list to return sample output
mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = '42\tOpen issue\n43\tAnother issue\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.__main__ import discover_candidate_issues
    # Force reimport to use patched subprocess
    issues = discover_candidate_issues('owner', 'repo')
    print(' '.join(map(str, issues)))
")

if [ "$discovery_output" != "42 43" ]; then
  test_fail "discover_candidate_issues should return [42, 43], got [$discovery_output]"
fi

# Test 6: discover_candidate_issues returns empty list on gh failure
discovery_fail_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue list to fail
mock_result = MagicMock()
mock_result.returncode = 1
mock_result.stderr = 'error: not authenticated'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.__main__ import discover_candidate_issues
    issues = discover_candidate_issues('owner', 'repo')
    print(len(issues))
")

if [ "$discovery_fail_output" != "0" ]; then
  test_fail "discover_candidate_issues should return empty list on failure, got count: $discovery_fail_output"
fi

# Test 7: query_issue_project_status returns status for valid project item
status_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
import json
from unittest.mock import patch, MagicMock

# Mock GraphQL response with issue project item status
graphql_response = {
    'data': {
        'repository': {
            'issue': {
                'projectItems': {
                    'nodes': [
                        {
                            'project': {'id': 'PVT_test123'},
                            'fieldValues': {
                                'nodes': [
                                    {'field': {'name': 'Status'}, 'name': 'Plan Accepted'}
                                ]
                            }
                        }
                    ]
                }
            }
        }
    }
}

mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = json.dumps(graphql_response)

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.__main__ import query_issue_project_status
    status = query_issue_project_status('owner', 'repo', 42, 'PVT_test123')
    print(status)
")

if [ "$status_output" != "Plan Accepted" ]; then
  test_fail "query_issue_project_status should return 'Plan Accepted', got: $status_output"
fi

# Test 8: query_issue_project_status returns empty string when issue not on project
status_missing_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
import json
from unittest.mock import patch, MagicMock

# Mock GraphQL response with issue on different project
graphql_response = {
    'data': {
        'repository': {
            'issue': {
                'projectItems': {
                    'nodes': [
                        {
                            'project': {'id': 'PVT_different'},
                            'fieldValues': {
                                'nodes': [
                                    {'field': {'name': 'Status'}, 'name': 'In Progress'}
                                ]
                            }
                        }
                    ]
                }
            }
        }
    }
}

mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = json.dumps(graphql_response)

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.__main__ import query_issue_project_status
    status = query_issue_project_status('owner', 'repo', 42, 'PVT_test123')
    print(f'status=[{status}]')
")

if [ "$status_missing_output" != "status=[]" ]; then
  test_fail "query_issue_project_status should return empty string for missing project, got: $status_missing_output"
fi

# Test 9: filter_ready_refinements returns issues with Proposed status + agentize:plan + agentize:refine labels
REFINEMENT_ITEMS='[
  {"content": {"number": 42, "labels": {"nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]}}, "fieldValueByName": {"name": "Proposed"}},
  {"content": {"number": 43, "labels": {"nodes": [{"name": "agentize:plan"}]}}, "fieldValueByName": {"name": "Proposed"}},
  {"content": {"number": 44, "labels": {"nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]}}, "fieldValueByName": {"name": "Plan Accepted"}},
  {"content": {"number": 45, "labels": {"nodes": [{"name": "agentize:refine"}]}}, "fieldValueByName": {"name": "Proposed"}}
]'

refine_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import json
from agentize.server.__main__ import filter_ready_refinements

items = json.loads('''$REFINEMENT_ITEMS''')
ready = filter_ready_refinements(items)
print(' '.join(map(str, ready)))
")

if [ "$refine_output" != "42" ]; then
  test_fail "Expected refinement issues [42], got [$refine_output]"
fi

# Test 10: filter_ready_refinements debug output contains [refine-filter] prefix
refine_debug_output=$(PYTHONPATH="$PROJECT_ROOT/python" HANDSOFF_DEBUG=1 python3 -c "
import json
from agentize.server.__main__ import filter_ready_refinements

items = json.loads('''$REFINEMENT_ITEMS''')
filter_ready_refinements(items)
" 2>&1)

if ! echo "$refine_debug_output" | grep -q '\[refine-filter\]'; then
  test_fail "Refinement debug output missing [refine-filter] prefix"
fi

if ! echo "$refine_debug_output" | grep -q 'missing agentize:refine'; then
  test_fail "Refinement debug output missing 'missing agentize:refine' reason"
fi

if ! echo "$refine_debug_output" | grep -q 'status != Proposed'; then
  test_fail "Refinement debug output missing 'status != Proposed' reason"
fi

# Test 11: filter_ready_refinements excludes issues with only agentize:refine (no agentize:plan)
refine_no_plan_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import json
from agentize.server.__main__ import filter_ready_refinements

items = [
  {'content': {'number': 45, 'labels': {'nodes': [{'name': 'agentize:refine'}]}}, 'fieldValueByName': {'name': 'Proposed'}}
]
ready = filter_ready_refinements(items)
print(len(ready))
")

if [ "$refine_no_plan_output" != "0" ]; then
  test_fail "Expected 0 refinement issues (missing agentize:plan), got count: $refine_no_plan_output"
fi

test_pass "server filter_ready_issues filtering and debug logs work correctly"
