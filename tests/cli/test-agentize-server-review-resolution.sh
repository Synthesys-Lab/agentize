#!/usr/bin/env bash
# Test: Server PR review resolution workflow (discover → filter → spawn → cleanup)

source "$(dirname "$0")/../common.sh"

test_info "Server PR review resolution workflow"

# Create a temporary Python test script to test the workflow
TMP_DIR=$(make_temp_dir "server-review-resolution")

# Create test script that validates the full workflow
cat > "$TMP_DIR/test_review_resolution_workflow.py" <<'PYTEST'
#!/usr/bin/env python3
"""Test PR review resolution workflow integration."""

import sys
import os

# Add the python module path
sys.path.insert(0, os.path.join(os.environ['PROJECT_ROOT'], 'python'))

from agentize.server.__main__ import (
    discover_candidate_prs,
    filter_ready_review_prs,
    has_unresolved_review_threads,
    spawn_review_resolution,
    resolve_issue_from_pr,
    query_issue_project_status,
    _cleanup_review_resolution,
)


def test_has_unresolved_review_threads_with_unresolved():
    """Test has_unresolved_review_threads returns True when unresolved threads exist."""
    from unittest.mock import patch
    import json

    # Mock GraphQL response with unresolved, non-outdated thread
    mock_response = {
        "data": {
            "repository": {
                "pullRequest": {
                    "reviewThreads": {
                        "nodes": [
                            {"isResolved": False, "isOutdated": False},
                            {"isResolved": True, "isOutdated": False},
                        ],
                        "pageInfo": {"hasNextPage": False}
                    }
                }
            }
        }
    }

    with patch('subprocess.run') as mock_run:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(mock_response)
        result = has_unresolved_review_threads('owner', 'repo', 123)

    assert result is True, f"Expected True (unresolved thread exists), got {result}"
    print("PASS: has_unresolved_review_threads returns True when unresolved threads exist")


def test_has_unresolved_review_threads_all_resolved():
    """Test has_unresolved_review_threads returns False when all threads are resolved."""
    from unittest.mock import patch
    import json

    # Mock GraphQL response with all resolved threads
    mock_response = {
        "data": {
            "repository": {
                "pullRequest": {
                    "reviewThreads": {
                        "nodes": [
                            {"isResolved": True, "isOutdated": False},
                            {"isResolved": True, "isOutdated": False},
                        ],
                        "pageInfo": {"hasNextPage": False}
                    }
                }
            }
        }
    }

    with patch('subprocess.run') as mock_run:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(mock_response)
        result = has_unresolved_review_threads('owner', 'repo', 123)

    assert result is False, f"Expected False (all resolved), got {result}"
    print("PASS: has_unresolved_review_threads returns False when all threads are resolved")


def test_has_unresolved_review_threads_outdated_excluded():
    """Test has_unresolved_review_threads excludes outdated threads."""
    from unittest.mock import patch
    import json

    # Mock GraphQL response with only outdated unresolved thread
    mock_response = {
        "data": {
            "repository": {
                "pullRequest": {
                    "reviewThreads": {
                        "nodes": [
                            {"isResolved": False, "isOutdated": True},  # Outdated
                            {"isResolved": True, "isOutdated": False},
                        ],
                        "pageInfo": {"hasNextPage": False}
                    }
                }
            }
        }
    }

    with patch('subprocess.run') as mock_run:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(mock_response)
        result = has_unresolved_review_threads('owner', 'repo', 123)

    assert result is False, f"Expected False (outdated excluded), got {result}"
    print("PASS: has_unresolved_review_threads excludes outdated threads")


def test_filter_ready_review_prs_requires_proposed_status():
    """Test filter_ready_review_prs skips non-Proposed status."""
    from unittest.mock import patch
    import json

    prs = [
        {'number': 100, 'headRefName': 'issue-100-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 101, 'headRefName': 'issue-101-fix', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock status: issue-100 is Proposed, issue-101 is In Progress
    def mock_status(owner, repo, issue_no, project_id):
        return 'Proposed' if issue_no == 100 else 'In Progress'

    # Mock threads: both have unresolved threads
    mock_response = {
        "data": {
            "repository": {
                "pullRequest": {
                    "reviewThreads": {
                        "nodes": [{"isResolved": False, "isOutdated": False}],
                        "pageInfo": {"hasNextPage": False}
                    }
                }
            }
        }
    }

    with patch('agentize.server.github.query_issue_project_status', mock_status), \
         patch('subprocess.run') as mock_run:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(mock_response)
        ready = filter_ready_review_prs(prs, 'owner', 'repo', 'PROJECT_ID')

    # Only issue 100 should be ready (Proposed status)
    pr_numbers = [pr_no for pr_no, issue_no in ready]
    assert 100 in pr_numbers, f"Expected PR 100 to be ready, got {ready}"
    assert 101 not in pr_numbers, f"Expected PR 101 to be skipped (In Progress), got {ready}"
    print("PASS: filter_ready_review_prs requires Proposed status")


def test_filter_ready_review_prs_requires_unresolved_threads():
    """Test filter_ready_review_prs skips PRs without unresolved threads."""
    from unittest.mock import patch
    import json

    prs = [
        {'number': 200, 'headRefName': 'issue-200-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 201, 'headRefName': 'issue-201-fix', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock: both have Proposed status
    with patch('agentize.server.github.query_issue_project_status', return_value='Proposed'), \
         patch('agentize.server.github.has_unresolved_review_threads') as mock_threads:
        # PR 200 has unresolved threads, PR 201 does not
        mock_threads.side_effect = lambda owner, repo, pr_no: pr_no == 200
        ready = filter_ready_review_prs(prs, 'owner', 'repo', 'PROJECT_ID')

    pr_numbers = [pr_no for pr_no, issue_no in ready]
    assert 200 in pr_numbers, f"Expected PR 200 to be ready, got {ready}"
    assert 201 not in pr_numbers, f"Expected PR 201 to be skipped (no threads), got {ready}"
    print("PASS: filter_ready_review_prs requires unresolved threads")


def test_filter_ready_review_prs_returns_tuples():
    """Test filter_ready_review_prs returns (pr_no, issue_no) tuples."""
    from unittest.mock import patch

    prs = [
        {'number': 300, 'headRefName': 'issue-42-feature', 'body': '', 'closingIssuesReferences': []},
    ]

    with patch('agentize.server.github.query_issue_project_status', return_value='Proposed'), \
         patch('agentize.server.github.has_unresolved_review_threads', return_value=True):
        ready = filter_ready_review_prs(prs, 'owner', 'repo', 'PROJECT_ID')

    assert len(ready) == 1, f"Expected 1 result, got {len(ready)}"
    pr_no, issue_no = ready[0]
    assert pr_no == 300, f"Expected PR number 300, got {pr_no}"
    assert issue_no == 42, f"Expected issue number 42 (from branch), got {issue_no}"
    print("PASS: filter_ready_review_prs returns (pr_no, issue_no) tuples")


def test_filter_ready_review_prs_skips_unresolvable_issue():
    """Test filter_ready_review_prs skips PRs without resolvable issue number."""
    from unittest.mock import patch

    prs = [
        {'number': 400, 'headRefName': 'random-branch', 'body': 'No issue ref', 'closingIssuesReferences': []},
    ]

    with patch('agentize.server.github.query_issue_project_status', return_value='Proposed'), \
         patch('agentize.server.github.has_unresolved_review_threads', return_value=True):
        ready = filter_ready_review_prs(prs, 'owner', 'repo', 'PROJECT_ID')

    assert len(ready) == 0, f"Expected 0 results (no resolvable issue), got {ready}"
    print("PASS: filter_ready_review_prs skips PRs without resolvable issue")


def test_spawn_review_resolution_signature():
    """Test spawn_review_resolution has correct signature."""
    import inspect
    sig = inspect.signature(spawn_review_resolution)
    params = list(sig.parameters.keys())

    expected = ['pr_no', 'issue_no', 'model']
    assert params == expected, f"Expected {expected}, got {params}"

    # Verify model has default
    model_param = sig.parameters['model']
    assert model_param.default is None, f"Expected model default None, got {model_param.default}"
    print("PASS: spawn_review_resolution has correct signature")


def test_cleanup_review_resolution_callable():
    """Test _cleanup_review_resolution is callable."""
    assert callable(_cleanup_review_resolution), "_cleanup_review_resolution should be callable"
    print("PASS: _cleanup_review_resolution is callable")


def test_full_workflow_simulation():
    """Simulate the full review resolution workflow with mock data."""
    from unittest.mock import patch

    # Simulate discover result (PRs with agentize:pr label)
    mock_prs = [
        {'number': 500, 'headRefName': 'issue-50-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 501, 'headRefName': 'issue-51-feature', 'body': '', 'closingIssuesReferences': []},
        {'number': 502, 'headRefName': 'issue-52-refactor', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock: issue 50 is Proposed, 51 is In Progress, 52 is Proposed
    def mock_status(owner, repo, issue_no, project_id):
        return 'Proposed' if issue_no in [50, 52] else 'In Progress'

    # Mock: PR 500 and 501 have unresolved threads, 502 does not
    def mock_threads(owner, repo, pr_no):
        return pr_no in [500, 501]

    with patch('agentize.server.github.query_issue_project_status', mock_status), \
         patch('agentize.server.github.has_unresolved_review_threads', mock_threads):
        ready = filter_ready_review_prs(mock_prs, 'owner', 'repo', 'PROJECT_ID')

    # Only PR 500 should be ready:
    # - PR 500: issue 50 is Proposed + has threads
    # - PR 501: issue 51 is In Progress (skipped)
    # - PR 502: issue 52 is Proposed but no threads (skipped)
    pr_numbers = [pr_no for pr_no, issue_no in ready]
    assert pr_numbers == [500], f"Expected [500], got {pr_numbers}"
    print("PASS: Full workflow simulation produces expected results")


def test_filter_ready_review_prs_debug_logging():
    """Test filter_ready_review_prs outputs debug logs when HANDSOFF_DEBUG=1."""
    from unittest.mock import patch
    import io
    import sys

    prs = [
        {'number': 600, 'headRefName': 'issue-60-fix', 'body': '', 'closingIssuesReferences': []},
    ]

    # Capture stderr for debug output
    old_stderr = sys.stderr
    sys.stderr = io.StringIO()

    try:
        with patch.dict(os.environ, {'HANDSOFF_DEBUG': '1'}), \
             patch('agentize.server.github.query_issue_project_status', return_value='Proposed'), \
             patch('agentize.server.github.has_unresolved_review_threads', return_value=True):
            filter_ready_review_prs(prs, 'owner', 'repo', 'PROJECT_ID')

        stderr_output = sys.stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    # Should have debug output about PR 600
    assert 'PR #600' in stderr_output, f"Expected debug output about PR #600, got: {stderr_output}"
    print("PASS: filter_ready_review_prs outputs debug logs with HANDSOFF_DEBUG=1")


if __name__ == '__main__':
    test_has_unresolved_review_threads_with_unresolved()
    test_has_unresolved_review_threads_all_resolved()
    test_has_unresolved_review_threads_outdated_excluded()
    test_filter_ready_review_prs_requires_proposed_status()
    test_filter_ready_review_prs_requires_unresolved_threads()
    test_filter_ready_review_prs_returns_tuples()
    test_filter_ready_review_prs_skips_unresolvable_issue()
    test_spawn_review_resolution_signature()
    test_cleanup_review_resolution_callable()
    test_full_workflow_simulation()
    test_filter_ready_review_prs_debug_logging()
    print("All tests passed!")
PYTEST

# Run the test
export PROJECT_ROOT
if python3 "$TMP_DIR/test_review_resolution_workflow.py"; then
  cleanup_dir "$TMP_DIR"
  test_pass "Server PR review resolution workflow"
else
  cleanup_dir "$TMP_DIR"
  test_fail "Server PR review resolution tests failed"
fi
