"""Tests for agentize.server PR review resolution workflow."""

import json
import os
import pytest
from unittest.mock import patch, MagicMock
import inspect

from agentize.server.__main__ import (
    filter_ready_review_prs,
    has_unresolved_review_threads,
    spawn_review_resolution,
    _cleanup_review_resolution,
)


class TestHasUnresolvedReviewThreads:
    """Tests for has_unresolved_review_threads function."""

    def test_returns_true_when_unresolved_threads_exist(self):
        """Test returns True when unresolved threads exist."""
        mock_response = {
            "data": {
                "repository": {
                    "pullRequest": {
                        "reviewThreads": {
                            "nodes": [
                                {"isResolved": False, "isOutdated": False},
                                {"isResolved": True, "isOutdated": False},
                            ],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = json.dumps(mock_response)
            result = has_unresolved_review_threads("owner", "repo", 123)

        assert result is True

    def test_returns_false_when_all_resolved(self):
        """Test returns False when all threads are resolved."""
        mock_response = {
            "data": {
                "repository": {
                    "pullRequest": {
                        "reviewThreads": {
                            "nodes": [
                                {"isResolved": True, "isOutdated": False},
                                {"isResolved": True, "isOutdated": False},
                            ],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = json.dumps(mock_response)
            result = has_unresolved_review_threads("owner", "repo", 123)

        assert result is False

    def test_excludes_outdated_threads(self):
        """Test excludes outdated threads from consideration."""
        mock_response = {
            "data": {
                "repository": {
                    "pullRequest": {
                        "reviewThreads": {
                            "nodes": [
                                {"isResolved": False, "isOutdated": True},  # Outdated
                                {"isResolved": True, "isOutdated": False},
                            ],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = json.dumps(mock_response)
            result = has_unresolved_review_threads("owner", "repo", 123)

        assert result is False


class TestFilterReadyReviewPRs:
    """Tests for filter_ready_review_prs function."""

    def test_requires_proposed_status(self):
        """Test skips non-Proposed status PRs."""
        prs = [
            {
                "number": 100,
                "headRefName": "issue-100-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 101,
                "headRefName": "issue-101-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        def mock_status(owner, repo, issue_no, project_id):
            return "Proposed" if issue_no == 100 else "In Progress"

        mock_response = {
            "data": {
                "repository": {
                    "pullRequest": {
                        "reviewThreads": {
                            "nodes": [{"isResolved": False, "isOutdated": False}],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }

        with patch(
            "agentize.server.github.query_issue_project_status", mock_status
        ), patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = json.dumps(mock_response)
            ready = filter_ready_review_prs(prs, "owner", "repo", "PROJECT_ID")

        pr_numbers = [pr_no for pr_no, issue_no in ready]
        assert 100 in pr_numbers
        assert 101 not in pr_numbers

    def test_requires_unresolved_threads(self):
        """Test skips PRs without unresolved threads."""
        prs = [
            {
                "number": 200,
                "headRefName": "issue-200-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 201,
                "headRefName": "issue-201-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Proposed"
        ), patch(
            "agentize.server.github.has_unresolved_review_threads"
        ) as mock_threads:
            mock_threads.side_effect = lambda owner, repo, pr_no: pr_no == 200
            ready = filter_ready_review_prs(prs, "owner", "repo", "PROJECT_ID")

        pr_numbers = [pr_no for pr_no, issue_no in ready]
        assert 200 in pr_numbers
        assert 201 not in pr_numbers

    def test_returns_tuples(self):
        """Test returns (pr_no, issue_no) tuples."""
        prs = [
            {
                "number": 300,
                "headRefName": "issue-42-feature",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Proposed"
        ), patch(
            "agentize.server.github.has_unresolved_review_threads", return_value=True
        ):
            ready = filter_ready_review_prs(prs, "owner", "repo", "PROJECT_ID")

        assert len(ready) == 1
        pr_no, issue_no = ready[0]
        assert pr_no == 300
        assert issue_no == 42

    def test_skips_unresolvable_issue(self):
        """Test skips PRs without resolvable issue number."""
        prs = [
            {
                "number": 400,
                "headRefName": "random-branch",
                "body": "No issue ref",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Proposed"
        ), patch(
            "agentize.server.github.has_unresolved_review_threads", return_value=True
        ):
            ready = filter_ready_review_prs(prs, "owner", "repo", "PROJECT_ID")

        assert len(ready) == 0


class TestSpawnReviewResolution:
    """Tests for spawn_review_resolution function."""

    def test_signature(self):
        """Test spawn_review_resolution has correct signature."""
        sig = inspect.signature(spawn_review_resolution)
        params = list(sig.parameters.keys())

        expected = ["pr_no", "issue_no", "model"]
        assert params == expected

        model_param = sig.parameters["model"]
        assert model_param.default is None


class TestCleanupReviewResolution:
    """Tests for _cleanup_review_resolution function."""

    def test_is_callable(self):
        """Test _cleanup_review_resolution is callable."""
        assert callable(_cleanup_review_resolution)


class TestFullWorkflowSimulation:
    """Tests for full review resolution workflow."""

    def test_full_workflow_simulation(self):
        """Simulate the full review resolution workflow with mock data."""
        mock_prs = [
            {
                "number": 500,
                "headRefName": "issue-50-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 501,
                "headRefName": "issue-51-feature",
                "body": "",
                "closingIssuesReferences": [],
            },
            {
                "number": 502,
                "headRefName": "issue-52-refactor",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        def mock_status(owner, repo, issue_no, project_id):
            return "Proposed" if issue_no in [50, 52] else "In Progress"

        def mock_threads(owner, repo, pr_no):
            return pr_no in [500, 501]

        with patch(
            "agentize.server.github.query_issue_project_status", mock_status
        ), patch("agentize.server.github.has_unresolved_review_threads", mock_threads):
            ready = filter_ready_review_prs(mock_prs, "owner", "repo", "PROJECT_ID")

        # Only PR 500 should be ready:
        # - PR 500: issue 50 is Proposed + has threads
        # - PR 501: issue 51 is In Progress (skipped)
        # - PR 502: issue 52 is Proposed but no threads (skipped)
        pr_numbers = [pr_no for pr_no, issue_no in ready]
        assert pr_numbers == [500]

    def test_debug_logging(self, monkeypatch, capsys):
        """Test debug logs are output when HANDSOFF_DEBUG=1."""
        monkeypatch.setenv("HANDSOFF_DEBUG", "1")

        prs = [
            {
                "number": 600,
                "headRefName": "issue-60-fix",
                "body": "",
                "closingIssuesReferences": [],
            },
        ]

        with patch(
            "agentize.server.github.query_issue_project_status", return_value="Proposed"
        ), patch(
            "agentize.server.github.has_unresolved_review_threads", return_value=True
        ):
            filter_ready_review_prs(prs, "owner", "repo", "PROJECT_ID")

        captured = capsys.readouterr()
        stderr_output = captured.err

        assert "PR #600" in stderr_output
