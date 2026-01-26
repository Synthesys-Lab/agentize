"""Tests for agentize.server GitHub discovery functions."""

import json
import pytest
from unittest.mock import patch, MagicMock

from agentize.server.__main__ import (
    get_repo_owner_name,
    discover_candidate_issues,
    query_issue_project_status,
    filter_ready_issues,
    filter_conflicting_prs,
    resolve_issue_from_pr,
    discover_candidate_prs,
    rebase_worktree,
    worktree_exists,
)
from agentize.server.github import (
    discover_candidate_feat_requests,
    lookup_project_graphql_id,
    _project_id_cache,
)


class TestGetRepoOwnerName:
    """Tests for get_repo_owner_name function."""

    def test_get_repo_owner_name_returns_owner_repo(self):
        """Test get_repo_owner_name returns correct format."""
        owner, repo = get_repo_owner_name()

        # Verify format is owner/repo (not empty, owner and repo exist)
        assert owner is not None
        assert repo is not None
        assert len(owner) > 0
        assert len(repo) > 0


class TestDiscoverCandidateIssues:
    """Tests for discover_candidate_issues function."""

    def test_discover_candidate_issues_returns_list(self):
        """Test discover_candidate_issues returns list of ints from gh output."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "42\tOpen issue\n43\tAnother issue\n"

        with patch("subprocess.run", return_value=mock_result):
            issues = discover_candidate_issues("owner", "repo")

        assert issues == [42, 43]

    def test_discover_candidate_issues_returns_empty_on_failure(self):
        """Test discover_candidate_issues returns empty list on gh failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stderr = "error: not authenticated"

        with patch("subprocess.run", return_value=mock_result):
            issues = discover_candidate_issues("owner", "repo")

        assert len(issues) == 0


class TestDiscoverCandidateFeatRequests:
    """Tests for discover_candidate_feat_requests function."""

    def test_discover_candidate_feat_requests_returns_list(self):
        """Test discover_candidate_feat_requests returns list of issue numbers."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "42\tFeature request 1\n43\tFeature request 2\n"

        with patch("subprocess.run", return_value=mock_result):
            issues = discover_candidate_feat_requests("owner", "repo")

        assert issues == [42, 43]

    def test_discover_candidate_feat_requests_returns_empty_on_failure(self):
        """Test discover_candidate_feat_requests returns empty list on gh failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stderr = "error: not authenticated"

        with patch("subprocess.run", return_value=mock_result):
            issues = discover_candidate_feat_requests("owner", "repo")

        assert len(issues) == 0


class TestQueryIssueProjectStatus:
    """Tests for query_issue_project_status function."""

    def test_query_issue_project_status_returns_status(self):
        """Test query_issue_project_status returns status for valid project item."""
        graphql_response = {
            "data": {
                "repository": {
                    "issue": {
                        "projectItems": {
                            "nodes": [
                                {
                                    "project": {"id": "PVT_test123"},
                                    "fieldValues": {
                                        "nodes": [
                                            {
                                                "field": {"name": "Status"},
                                                "name": "Plan Accepted",
                                            }
                                        ]
                                    },
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

        with patch("subprocess.run", return_value=mock_result):
            status = query_issue_project_status("owner", "repo", 42, "PVT_test123")

        assert status == "Plan Accepted"

    def test_query_issue_project_status_returns_empty_when_not_on_project(self):
        """Test query_issue_project_status returns empty string when issue not on project."""
        graphql_response = {
            "data": {
                "repository": {
                    "issue": {
                        "projectItems": {
                            "nodes": [
                                {
                                    "project": {"id": "PVT_different"},
                                    "fieldValues": {
                                        "nodes": [
                                            {
                                                "field": {"name": "Status"},
                                                "name": "In Progress",
                                            }
                                        ]
                                    },
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

        with patch("subprocess.run", return_value=mock_result):
            status = query_issue_project_status("owner", "repo", 42, "PVT_test123")

        assert status == ""


class TestPRDiscoveryAndFiltering:
    """Tests for PR discovery and filtering functions."""

    def test_filter_conflicting_prs_basic(self):
        """Test filter_conflicting_prs returns PR numbers with CONFLICTING status."""
        prs = [
            {
                "number": 123,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-123-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 124,
                "mergeable": "MERGEABLE",
                "headRefName": "issue-124-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 125,
                "mergeable": "UNKNOWN",
                "headRefName": "issue-125-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Backlog"
        ):
            conflicting = filter_conflicting_prs(
                prs, "test-owner", "test-repo", "PROJECT_ID"
            )

        assert conflicting == [123]

    def test_filter_conflicting_prs_empty(self):
        """Test filter_conflicting_prs handles empty input."""
        with patch(
            "agentize.server.github.query_issue_project_status", return_value=""
        ):
            conflicting = filter_conflicting_prs(
                [], "test-owner", "test-repo", "PROJECT_ID"
            )

        assert conflicting == []

    def test_filter_conflicting_prs_skips_rebasing_status(self):
        """Test filter_conflicting_prs skips PRs with Rebasing status."""
        prs = [
            {
                "number": 400,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-400-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 401,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-401-feature",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 402,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-402-refactor",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        def mock_status(owner, repo, issue_no, project_id):
            if issue_no == 401:
                return "Rebasing"
            return "Backlog"

        with patch("agentize.server.github.query_issue_project_status", mock_status):
            conflicting = filter_conflicting_prs(
                prs, "test-owner", "test-repo", "PROJECT_ID"
            )

        assert 401 not in conflicting
        assert 400 in conflicting
        assert 402 in conflicting

    def test_filter_conflicting_prs_multiple(self):
        """Test filter_conflicting_prs with multiple conflicting PRs."""
        prs = [
            {
                "number": 100,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-100-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 101,
                "mergeable": "MERGEABLE",
                "headRefName": "issue-101-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 102,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-102-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 103,
                "mergeable": "UNKNOWN",
                "headRefName": "issue-103-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 104,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-104-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Backlog"
        ):
            conflicting = filter_conflicting_prs(
                prs, "test-owner", "test-repo", "PROJECT_ID"
            )

        assert conflicting == [100, 102, 104]

    def test_filter_conflicting_prs_handles_unresolvable_issue(self):
        """Test filter_conflicting_prs queues PRs with unresolvable issue numbers."""
        prs = [
            {
                "number": 600,
                "mergeable": "CONFLICTING",
                "headRefName": "random-branch",
                "body": "No issue ref",
                "closingIssuesReferences": [],
            },
        ]

        call_count = [0]

        def mock_status(owner, repo, issue_no, project_id):
            call_count[0] += 1
            return ""

        with patch("agentize.server.github.query_issue_project_status", mock_status):
            conflicting = filter_conflicting_prs(
                prs, "test-owner", "test-repo", "PROJECT_ID"
            )

        # PR should be queued since we can't check status without issue number
        assert 600 in conflicting
        # Status should not be queried for unresolvable PRs
        assert call_count[0] == 0


class TestResolveIssueFromPR:
    """Tests for resolve_issue_from_pr function."""

    def test_resolve_issue_from_pr_branch_name(self):
        """Test issue resolution from branch name."""
        pr = {
            "headRefName": "issue-42-add-feature",
            "body": "",
            "closingIssuesReferences": [],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no == 42

    def test_resolve_issue_from_pr_closing_refs(self):
        """Test issue resolution from closingIssuesReferences."""
        pr = {
            "headRefName": "feature-branch",
            "body": "",
            "closingIssuesReferences": [{"number": 55}],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no == 55

    def test_resolve_issue_from_pr_body(self):
        """Test issue resolution from PR body."""
        pr = {
            "headRefName": "feature-branch",
            "body": "Fixes #99 in the codebase",
            "closingIssuesReferences": [],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no == 99

    def test_resolve_issue_from_pr_no_match(self):
        """Test issue resolution when no pattern matches."""
        pr = {
            "headRefName": "feature-branch",
            "body": "No issue reference",
            "closingIssuesReferences": [],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no is None

    def test_resolve_issue_priority_branch_first(self):
        """Test that branch name takes priority over other resolution methods."""
        pr = {
            "headRefName": "issue-42-add-feature",
            "body": "Fixes #99",
            "closingIssuesReferences": [{"number": 55}],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no == 42

    def test_resolve_issue_fixes_keyword(self):
        """Test resolution from PR body with 'Fixes #N' pattern."""
        pr = {
            "headRefName": "feature-branch",
            "body": "Fixes #77 by updating the handler",
            "closingIssuesReferences": [],
        }
        issue_no = resolve_issue_from_pr(pr)
        assert issue_no == 77


class TestRebaseWorktreeSignature:
    """Tests for rebase_worktree function signature."""

    def test_rebase_return_type(self):
        """Test that rebase_worktree has correct signature."""
        import inspect

        sig = inspect.signature(rebase_worktree)

        # Check parameters (pr_no required, issue_no and model optional)
        params = list(sig.parameters.keys())
        assert params == ["pr_no", "issue_no", "model"]

        # Verify issue_no has a default value (optional parameter)
        issue_no_param = sig.parameters["issue_no"]
        assert issue_no_param.default is None

        # Verify model has a default value (optional parameter)
        model_param = sig.parameters["model"]
        assert model_param.default is None


class TestWorkflowIntegration:
    """Tests for workflow integration."""

    def test_workflow_integration_structure(self):
        """Test that all workflow components are accessible and callable."""
        assert callable(discover_candidate_prs)
        assert callable(filter_conflicting_prs)
        assert callable(resolve_issue_from_pr)
        assert callable(rebase_worktree)
        assert callable(worktree_exists)

    def test_full_workflow_simulation(self):
        """Simulate the full workflow with mock data."""
        mock_prs = [
            {
                "number": 300,
                "mergeable": "CONFLICTING",
                "headRefName": "issue-300-bugfix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 301,
                "mergeable": "MERGEABLE",
                "headRefName": "issue-301-feature",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 302,
                "mergeable": "CONFLICTING",
                "headRefName": "feature-branch",
                "body": "Fixes #302",
                "closingIssuesReferences": [],
            },
        ]

        # Step 1: Filter conflicting
        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Backlog"
        ):
            conflicting_pr_numbers = filter_conflicting_prs(
                mock_prs, "test-owner", "test-repo", "PROJECT_ID"
            )

        assert conflicting_pr_numbers == [300, 302]

        # Step 2: Resolve issue numbers for each conflicting PR
        resolved = []
        for pr_no in conflicting_pr_numbers:
            pr_metadata = next(
                (p for p in mock_prs if p.get("number") == pr_no), None
            )
            if pr_metadata:
                issue_no = resolve_issue_from_pr(pr_metadata)
                if issue_no:
                    resolved.append((pr_no, issue_no))

        expected_resolved = [(300, 300), (302, 302)]
        assert resolved == expected_resolved


class TestLookupProjectGraphQLId:
    """Tests for lookup_project_graphql_id function."""

    def test_lookup_project_uses_correct_arg_types(self):
        """Test lookup_project_graphql_id passes -f for strings and -F for ints.

        This ensures GraphQL variables are typed correctly:
        - -f owner=TestOrg (string variable)
        - -F projectNumber=42 (integer variable)
        """
        # Clear cache to ensure fresh lookup
        _project_id_cache.clear()

        captured_args = []

        def capture_subprocess_run(args, **kwargs):
            captured_args.extend(args)
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = json.dumps(
                {"data": {"repositoryOwner": {"projectV2": {"id": "PVT_xxx"}}}}
            )
            return mock_result

        with patch("subprocess.run", side_effect=capture_subprocess_run):
            lookup_project_graphql_id("TestOrg", 42)

        # Verify -f owner=TestOrg (string variable for repositoryOwner query)
        assert "-f" in captured_args
        owner_idx = captured_args.index("-f") + 1
        # Check that the next arg after -f for owner starts with owner=
        owner_args = [
            captured_args[i + 1]
            for i, arg in enumerate(captured_args)
            if arg == "-f" and "owner=" in captured_args[i + 1]
        ]
        assert any("owner=TestOrg" in arg for arg in owner_args)

        # Verify -F projectNumber=42 (integer variable)
        assert "-F" in captured_args
        project_args = [
            captured_args[i + 1]
            for i, arg in enumerate(captured_args)
            if arg == "-F"
        ]
        assert any("projectNumber=42" in arg for arg in project_args)

    def test_lookup_project_no_variables_pattern(self):
        """Test lookup_project_graphql_id does not use -f variables= pattern.

        The old broken pattern was -f variables={"owner":..., "projectNumber":...}
        The correct pattern uses typed args: -f owner=... -F projectNumber=...
        """
        # Clear cache to ensure fresh lookup
        _project_id_cache.clear()

        captured_args = []

        def capture_subprocess_run(args, **kwargs):
            captured_args.extend(args)
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = json.dumps(
                {"data": {"repositoryOwner": {"projectV2": {"id": "PVT_xxx"}}}}
            )
            return mock_result

        with patch("subprocess.run", side_effect=capture_subprocess_run):
            lookup_project_graphql_id("TestOrg", 42)

        # Should NOT have -f variables= (old broken pattern)
        args_str = " ".join(str(arg) for arg in captured_args)
        assert "variables=" not in args_str
