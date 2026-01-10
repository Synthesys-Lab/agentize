#!/usr/bin/env bash
# Test: Server PR discovery and filtering functions

source "$(dirname "$0")/../common.sh"

test_info "Server PR discovery and filtering functions"

# Create a temporary Python test script to test the server functions
TMP_DIR=$(make_temp_dir "server-pr-discovery")

# Create test script that imports and tests the functions
cat > "$TMP_DIR/test_pr_discovery.py" <<'PYTEST'
#!/usr/bin/env python3
"""Test PR discovery and filtering functions."""

import sys
import os

# Add the python module path
sys.path.insert(0, os.path.join(os.environ['PROJECT_ROOT'], 'python'))

from agentize.server.__main__ import filter_ready_issues, filter_conflicting_prs, resolve_issue_from_pr

def test_filter_conflicting_prs_basic():
    """Test that filter_conflicting_prs returns PR numbers with CONFLICTING status."""
    prs = [
        {'number': 123, 'mergeable': 'CONFLICTING'},
        {'number': 124, 'mergeable': 'MERGEABLE'},
        {'number': 125, 'mergeable': 'UNKNOWN'},
    ]

    conflicting = filter_conflicting_prs(prs)
    assert conflicting == [123], f"Expected [123], got {conflicting}"
    print("PASS: filter_conflicting_prs returns correct PRs")

def test_filter_conflicting_prs_empty():
    """Test that filter_conflicting_prs handles empty input."""
    conflicting = filter_conflicting_prs([])
    assert conflicting == [], f"Expected [], got {conflicting}"
    print("PASS: filter_conflicting_prs handles empty input")

def test_resolve_issue_from_pr_branch_name():
    """Test issue resolution from branch name."""
    pr = {'headRefName': 'issue-42-add-feature', 'body': '', 'closingIssuesReferences': []}
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 42, f"Expected 42, got {issue_no}"
    print("PASS: resolve_issue_from_pr extracts from branch name")

def test_resolve_issue_from_pr_closing_refs():
    """Test issue resolution from closingIssuesReferences."""
    pr = {'headRefName': 'feature-branch', 'body': '', 'closingIssuesReferences': [{'number': 55}]}
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 55, f"Expected 55, got {issue_no}"
    print("PASS: resolve_issue_from_pr extracts from closingIssuesReferences")

def test_resolve_issue_from_pr_body():
    """Test issue resolution from PR body."""
    pr = {'headRefName': 'feature-branch', 'body': 'Fixes #99 in the codebase', 'closingIssuesReferences': []}
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 99, f"Expected 99, got {issue_no}"
    print("PASS: resolve_issue_from_pr extracts from body")

def test_resolve_issue_from_pr_no_match():
    """Test issue resolution when no pattern matches."""
    pr = {'headRefName': 'feature-branch', 'body': 'No issue reference', 'closingIssuesReferences': []}
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no is None, f"Expected None, got {issue_no}"
    print("PASS: resolve_issue_from_pr returns None when no match")

def test_filter_ready_issues_basic():
    """Test that filter_ready_issues returns issue numbers with Plan Accepted status and agentize:plan label."""
    items = [
        {
            'content': {
                'number': 42,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}
            },
            'fieldValueByName': {'name': 'Plan Accepted'}
        },
        {
            'content': {
                'number': 43,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}
            },
            'fieldValueByName': {'name': 'Backlog'}
        },
        {
            'content': {
                'number': 44,
                'labels': {'nodes': [{'name': 'feature'}]}
            },
            'fieldValueByName': {'name': 'Plan Accepted'}
        }
    ]

    ready = filter_ready_issues(items)
    assert ready == [42], f"Expected [42], got {ready}"
    print("PASS: filter_ready_issues returns correct issues")

def test_filter_ready_issues_empty():
    """Test that filter_ready_issues handles empty input."""
    ready = filter_ready_issues([])
    assert ready == [], f"Expected [], got {ready}"
    print("PASS: filter_ready_issues handles empty input")

def test_filter_ready_issues_missing_content():
    """Test that filter_ready_issues handles items without content."""
    items = [
        {
            'fieldValueByName': {'name': 'Plan Accepted'}
        },
        {
            'content': None,
            'fieldValueByName': {'name': 'Plan Accepted'}
        }
    ]

    ready = filter_ready_issues(items)
    assert ready == [], f"Expected [], got {ready}"
    print("PASS: filter_ready_issues handles missing content")

def test_filter_ready_issues_missing_status():
    """Test that filter_ready_issues handles items without status field."""
    items = [
        {
            'content': {
                'number': 45,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}
            },
            'fieldValueByName': None
        },
        {
            'content': {
                'number': 46,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}
            }
        }
    ]

    ready = filter_ready_issues(items)
    assert ready == [], f"Expected [], got {ready}"
    print("PASS: filter_ready_issues handles missing status field")

if __name__ == '__main__':
    test_filter_conflicting_prs_basic()
    test_filter_conflicting_prs_empty()
    test_resolve_issue_from_pr_branch_name()
    test_resolve_issue_from_pr_closing_refs()
    test_resolve_issue_from_pr_body()
    test_resolve_issue_from_pr_no_match()
    test_filter_ready_issues_basic()
    test_filter_ready_issues_empty()
    test_filter_ready_issues_missing_content()
    test_filter_ready_issues_missing_status()
    print("All tests passed!")
PYTEST

# Run the test
export PROJECT_ROOT
if python3 "$TMP_DIR/test_pr_discovery.py"; then
  cleanup_dir "$TMP_DIR"
  test_pass "Server PR discovery and filtering functions"
else
  cleanup_dir "$TMP_DIR"
  test_fail "Server PR discovery tests failed"
fi
