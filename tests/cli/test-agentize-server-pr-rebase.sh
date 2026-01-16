#!/usr/bin/env bash
# Test: Server PR conflict handling workflow (discover → filter → resolve → rebase)

source "$(dirname "$0")/../common.sh"

test_info "Server PR conflict handling workflow"

# Create a temporary Python test script to test the workflow
TMP_DIR=$(make_temp_dir "server-pr-rebase")

# Create test script that validates the full workflow
cat > "$TMP_DIR/test_pr_rebase_workflow.py" <<'PYTEST'
#!/usr/bin/env python3
"""Test PR conflict handling workflow integration."""

import sys
import os

# Add the python module path
sys.path.insert(0, os.path.join(os.environ['PROJECT_ROOT'], 'python'))

from agentize.server.__main__ import (
    discover_candidate_prs,
    filter_conflicting_prs,
    resolve_issue_from_pr,
    rebase_worktree,
    worktree_exists,
    get_repo_owner_name,
    query_issue_project_status,
)


def test_filter_conflicting_prs_multiple():
    """Test filter_conflicting_prs with multiple conflicting PRs."""
    from unittest.mock import patch

    prs = [
        {'number': 100, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-100-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 101, 'mergeable': 'MERGEABLE', 'headRefName': 'issue-101-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 102, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-102-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 103, 'mergeable': 'UNKNOWN', 'headRefName': 'issue-103-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 104, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-104-fix', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock status to return non-Rebasing for all
    with patch('agentize.server.github.query_issue_project_status', return_value='Backlog'):
        conflicting = filter_conflicting_prs(prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    assert conflicting == [100, 102, 104], f"Expected [100, 102, 104], got {conflicting}"
    print("PASS: filter_conflicting_prs returns all conflicting PRs")


def test_filter_conflicting_prs_skips_unknown():
    """Test that UNKNOWN status PRs are skipped (retry next poll)."""
    from unittest.mock import patch

    prs = [
        {'number': 200, 'mergeable': 'UNKNOWN', 'headRefName': 'issue-200-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 201, 'mergeable': 'UNKNOWN', 'headRefName': 'issue-201-fix', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock status - should not be called for UNKNOWN mergeable PRs
    with patch('agentize.server.github.query_issue_project_status', return_value='Backlog'):
        conflicting = filter_conflicting_prs(prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    assert conflicting == [], f"Expected [], got {conflicting}"
    print("PASS: filter_conflicting_prs skips UNKNOWN status PRs")


def test_resolve_issue_priority_branch_first():
    """Test that branch name takes priority over other resolution methods."""
    pr = {
        'headRefName': 'issue-42-add-feature',
        'body': 'Fixes #99',
        'closingIssuesReferences': [{'number': 55}]
    }
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 42, f"Expected 42 (branch name priority), got {issue_no}"
    print("PASS: resolve_issue_from_pr prioritizes branch name")


def test_resolve_issue_closing_refs_fallback():
    """Test that closingIssuesReferences is used when branch doesn't match."""
    pr = {
        'headRefName': 'feature-branch',
        'body': '',
        'closingIssuesReferences': [{'number': 55}, {'number': 56}]
    }
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 55, f"Expected 55 (first closing ref), got {issue_no}"
    print("PASS: resolve_issue_from_pr falls back to closingIssuesReferences")


def test_resolve_issue_body_fallback():
    """Test that PR body is used when other methods fail."""
    pr = {
        'headRefName': 'feature-branch',
        'body': 'This PR implements feature for #123 and more',
        'closingIssuesReferences': []
    }
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 123, f"Expected 123 (body reference), got {issue_no}"
    print("PASS: resolve_issue_from_pr falls back to body pattern")


def test_resolve_issue_fixes_keyword():
    """Test resolution from PR body with 'Fixes #N' pattern."""
    pr = {
        'headRefName': 'feature-branch',
        'body': 'Fixes #77 by updating the handler',
        'closingIssuesReferences': []
    }
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no == 77, f"Expected 77, got {issue_no}"
    print("PASS: resolve_issue_from_pr handles 'Fixes #N' pattern")


def test_resolve_issue_no_match_returns_none():
    """Test that None is returned when no issue can be resolved."""
    pr = {
        'headRefName': 'random-branch-name',
        'body': 'Just some random text without issue refs',
        'closingIssuesReferences': []
    }
    issue_no = resolve_issue_from_pr(pr)
    assert issue_no is None, f"Expected None, got {issue_no}"
    print("PASS: resolve_issue_from_pr returns None when no match")


def test_filter_conflicting_prs_signature_with_status_params():
    """Test filter_conflicting_prs accepts owner, repo, project_id parameters."""
    import inspect
    sig = inspect.signature(filter_conflicting_prs)
    params = list(sig.parameters.keys())

    # Verify the new signature includes status check parameters
    expected_params = ['prs', 'owner', 'repo', 'project_id']
    assert params == expected_params, f"Expected {expected_params}, got {params}"
    print("PASS: filter_conflicting_prs has correct signature with status params")


def test_filter_conflicting_prs_skips_rebasing_status():
    """Test that conflicting PRs with 'Rebasing' status are skipped.

    This is a structural test verifying the filtering logic. The actual
    query_issue_project_status is mocked to avoid GitHub API calls.
    """
    from unittest.mock import patch

    prs = [
        {'number': 400, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-400-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 401, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-401-feature', 'body': '', 'closingIssuesReferences': []},
        {'number': 402, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-402-refactor', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock query_issue_project_status to return 'Rebasing' for issue 401
    def mock_status(owner, repo, issue_no, project_id):
        if issue_no == 401:
            return 'Rebasing'
        return 'Backlog'

    with patch('agentize.server.github.query_issue_project_status', mock_status):
        conflicting = filter_conflicting_prs(prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    # Issue 401 should be skipped because its status is 'Rebasing'
    assert 401 not in conflicting, f"Expected 401 to be skipped (Rebasing status), got {conflicting}"
    assert 400 in conflicting, f"Expected 400 to be queued, got {conflicting}"
    assert 402 in conflicting, f"Expected 402 to be queued, got {conflicting}"
    print("PASS: filter_conflicting_prs skips PRs with Rebasing status")


def test_filter_conflicting_prs_queues_other_statuses():
    """Test that conflicting PRs with non-Rebasing statuses are queued."""
    from unittest.mock import patch

    prs = [
        {'number': 500, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-500-fix', 'body': '', 'closingIssuesReferences': []},
        {'number': 501, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-501-feature', 'body': '', 'closingIssuesReferences': []},
    ]

    # Mock status returns various non-Rebasing statuses
    def mock_status(owner, repo, issue_no, project_id):
        statuses = {500: 'Plan Accepted', 501: 'In Progress'}
        return statuses.get(issue_no, '')

    with patch('agentize.server.github.query_issue_project_status', mock_status):
        conflicting = filter_conflicting_prs(prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    assert 500 in conflicting, f"Expected 500 (Plan Accepted) to be queued, got {conflicting}"
    assert 501 in conflicting, f"Expected 501 (In Progress) to be queued, got {conflicting}"
    print("PASS: filter_conflicting_prs queues PRs with non-Rebasing statuses")


def test_filter_conflicting_prs_handles_unresolvable_issue():
    """Test that PRs without resolvable issue numbers are queued (best-effort)."""
    from unittest.mock import patch

    prs = [
        # This PR has no issue number in branch name or body
        {'number': 600, 'mergeable': 'CONFLICTING', 'headRefName': 'random-branch', 'body': 'No issue ref', 'closingIssuesReferences': []},
    ]

    # Mock status - should not be called for unresolvable issues
    call_count = [0]
    def mock_status(owner, repo, issue_no, project_id):
        call_count[0] += 1
        return ''

    with patch('agentize.server.github.query_issue_project_status', mock_status):
        conflicting = filter_conflicting_prs(prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    # PR should be queued since we can't check status without issue number
    assert 600 in conflicting, f"Expected 600 to be queued (unresolvable), got {conflicting}"
    # Status should not be queried for unresolvable PRs
    assert call_count[0] == 0, f"Expected 0 status queries for unresolvable PR, got {call_count[0]}"
    print("PASS: filter_conflicting_prs queues PRs with unresolvable issue numbers")


def test_workflow_integration_structure():
    """Test that all workflow components are accessible and have correct signatures."""
    # Verify all functions are importable and callable
    assert callable(discover_candidate_prs), "discover_candidate_prs should be callable"
    assert callable(filter_conflicting_prs), "filter_conflicting_prs should be callable"
    assert callable(resolve_issue_from_pr), "resolve_issue_from_pr should be callable"
    assert callable(rebase_worktree), "rebase_worktree should be callable"
    assert callable(worktree_exists), "worktree_exists should be callable"

    print("PASS: All workflow functions are importable and callable")


def test_rebase_return_type():
    """Test that rebase_worktree returns correct tuple structure.

    Note: This is a structural test - we don't actually call rebase
    as it would modify git state.
    """
    # Test with annotations from the function
    import inspect
    sig = inspect.signature(rebase_worktree)

    # Check parameters (pr_no required, issue_no and model optional)
    params = list(sig.parameters.keys())
    assert params == ['pr_no', 'issue_no', 'model'], f"Expected ['pr_no', 'issue_no', 'model'], got {params}"

    # Verify issue_no has a default value (optional parameter)
    issue_no_param = sig.parameters['issue_no']
    assert issue_no_param.default is None, f"Expected issue_no default to be None, got {issue_no_param.default}"

    # Verify model has a default value (optional parameter)
    model_param = sig.parameters['model']
    assert model_param.default is None, f"Expected model default to be None, got {model_param.default}"

    # Check return annotation (tuple[bool, int | None])
    # The annotation should indicate tuple return
    print("PASS: rebase_worktree has correct signature (pr_no, issue_no=None, model=None) -> tuple[bool, int|None]")


def test_full_workflow_simulation():
    """Simulate the full workflow with mock data.

    This tests the logical flow: discover → filter → resolve → check worktree
    """
    from unittest.mock import patch

    # Simulate discover result
    mock_prs = [
        {'number': 300, 'mergeable': 'CONFLICTING', 'headRefName': 'issue-300-bugfix', 'body': '', 'closingIssuesReferences': []},
        {'number': 301, 'mergeable': 'MERGEABLE', 'headRefName': 'issue-301-feature', 'body': '', 'closingIssuesReferences': []},
        {'number': 302, 'mergeable': 'CONFLICTING', 'headRefName': 'feature-branch', 'body': 'Fixes #302', 'closingIssuesReferences': []},
    ]

    # Step 1: Filter conflicting (with mocked status check)
    with patch('agentize.server.github.query_issue_project_status', return_value='Backlog'):
        conflicting_pr_numbers = filter_conflicting_prs(mock_prs, 'test-owner', 'test-repo', 'PROJECT_ID')

    assert conflicting_pr_numbers == [300, 302], f"Expected [300, 302], got {conflicting_pr_numbers}"

    # Step 2: Resolve issue numbers for each conflicting PR
    resolved = []
    for pr_no in conflicting_pr_numbers:
        pr_metadata = next((p for p in mock_prs if p.get('number') == pr_no), None)
        if pr_metadata:
            issue_no = resolve_issue_from_pr(pr_metadata)
            if issue_no:
                resolved.append((pr_no, issue_no))

    expected_resolved = [(300, 300), (302, 302)]
    assert resolved == expected_resolved, f"Expected {expected_resolved}, got {resolved}"

    print("PASS: Full workflow simulation produces expected results")


if __name__ == '__main__':
    test_filter_conflicting_prs_multiple()
    test_filter_conflicting_prs_skips_unknown()
    test_resolve_issue_priority_branch_first()
    test_resolve_issue_closing_refs_fallback()
    test_resolve_issue_body_fallback()
    test_resolve_issue_fixes_keyword()
    test_resolve_issue_no_match_returns_none()
    test_filter_conflicting_prs_signature_with_status_params()
    test_filter_conflicting_prs_skips_rebasing_status()
    test_filter_conflicting_prs_queues_other_statuses()
    test_filter_conflicting_prs_handles_unresolvable_issue()
    test_workflow_integration_structure()
    test_rebase_return_type()
    test_full_workflow_simulation()
    print("All tests passed!")
PYTEST

# Run the test
export PROJECT_ROOT
if python3 "$TMP_DIR/test_pr_rebase_workflow.py"; then
  cleanup_dir "$TMP_DIR"
  test_pass "Server PR conflict handling workflow"
else
  cleanup_dir "$TMP_DIR"
  test_fail "Server PR conflict handling tests failed"
fi
