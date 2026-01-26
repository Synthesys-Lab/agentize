"""Tests for agentize.server GitHub filtering functions."""

import json
import pytest
from unittest.mock import patch, MagicMock

from agentize.server.__main__ import (
    filter_ready_issues,
    filter_ready_refinements,
    filter_ready_feat_requests,
)
from agentize.server.github import (
    filter_ready_feat_requests as github_filter_ready_feat_requests,
)


class TestFilterReadyIssues:
    """Tests for filter_ready_issues function."""

    def test_filter_ready_issues_returns_expected(self):
        """Test filter_ready_issues returns issues with Plan Accepted and agentize:plan."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:plan"}, {"name": "bug"}]},
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
            {
                "content": {
                    "number": 43,
                    "labels": {"nodes": [{"name": "enhancement"}]},
                },
                "fieldValueByName": {"name": "Backlog"},
            },
            {
                "content": {
                    "number": 44,
                    "labels": {"nodes": [{"name": "feature"}]},
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
            {"content": None, "fieldValueByName": None},
        ]

        ready = filter_ready_issues(items)

        assert ready == [42]

    def test_filter_ready_issues_debug_output(self, capsys):
        """Test filter_ready_issues debug output contains expected tokens."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:plan"}, {"name": "bug"}]},
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
            {
                "content": {
                    "number": 43,
                    "labels": {"nodes": [{"name": "enhancement"}]},
                },
                "fieldValueByName": {"name": "Backlog"},
            },
        ]

        with patch("agentize.server.github._is_debug_enabled", return_value=True):
            filter_ready_issues(items)

        captured = capsys.readouterr()
        debug_output = captured.err

        assert "decision:" in debug_output
        assert "READY" in debug_output
        assert "SKIP" in debug_output
        assert "Summary:" in debug_output

    def test_filter_ready_issues_debug_does_not_alter_result(self):
        """Test that debug mode doesn't alter the returned list."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:plan"}]},
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
        ]

        with patch("agentize.server.github._is_debug_enabled", return_value=True):
            ready = filter_ready_issues(items)

        assert ready == [42]

    def test_filter_ready_issues_handles_empty_input(self):
        """Test filter_ready_issues handles empty input."""
        ready = filter_ready_issues([])
        assert ready == []

    def test_filter_ready_issues_handles_missing_content(self):
        """Test filter_ready_issues handles items without content."""
        items = [
            {"fieldValueByName": {"name": "Plan Accepted"}},
            {"content": None, "fieldValueByName": {"name": "Plan Accepted"}},
        ]

        ready = filter_ready_issues(items)
        assert ready == []

    def test_filter_ready_issues_handles_missing_status(self):
        """Test filter_ready_issues handles items without status field."""
        items = [
            {
                "content": {
                    "number": 45,
                    "labels": {"nodes": [{"name": "agentize:plan"}]},
                },
                "fieldValueByName": None,
            },
            {
                "content": {
                    "number": 46,
                    "labels": {"nodes": [{"name": "agentize:plan"}]},
                },
            },
        ]

        ready = filter_ready_issues(items)
        assert ready == []


class TestFilterReadyRefinements:
    """Tests for filter_ready_refinements function."""

    def test_filter_ready_refinements_returns_expected(self):
        """Test filter_ready_refinements returns issues with correct labels and status."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {
                        "nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]
                    },
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 43,
                    "labels": {"nodes": [{"name": "agentize:plan"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 44,
                    "labels": {
                        "nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]
                    },
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
            {
                "content": {
                    "number": 45,
                    "labels": {"nodes": [{"name": "agentize:refine"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            },
        ]

        ready = filter_ready_refinements(items)

        assert ready == [42]

    def test_filter_ready_refinements_debug_output(self, capsys):
        """Test filter_ready_refinements debug output contains expected messages."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {
                        "nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]
                    },
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 43,
                    "labels": {"nodes": [{"name": "agentize:plan"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 44,
                    "labels": {
                        "nodes": [{"name": "agentize:plan"}, {"name": "agentize:refine"}]
                    },
                },
                "fieldValueByName": {"name": "Plan Accepted"},
            },
        ]

        with patch("agentize.server.github._is_debug_enabled", return_value=True):
            filter_ready_refinements(items)

        captured = capsys.readouterr()
        debug_output = captured.err

        assert "decision:" in debug_output
        assert "missing agentize:refine" in debug_output
        assert "status != Proposed" in debug_output

    def test_filter_ready_refinements_excludes_no_plan_label(self):
        """Test filter_ready_refinements excludes issues with only agentize:refine."""
        items = [
            {
                "content": {
                    "number": 45,
                    "labels": {"nodes": [{"name": "agentize:refine"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            }
        ]

        ready = filter_ready_refinements(items)

        assert len(ready) == 0


class TestFilterReadyFeatRequests:
    """Tests for filter_ready_feat_requests function.

    Feat-request issues are eligible for planning when:
    - Has 'agentize:dev-req' label
    - Does NOT have 'agentize:plan' label
    - Status == 'Proposed' (concurrency control)
    """

    def test_filter_ready_feat_requests_accepts_proposed_status(self):
        """Test filter_ready_feat_requests accepts issues with Status == 'Proposed'."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            },
        ]

        ready = filter_ready_feat_requests(items)

        assert ready == [42]

    def test_filter_ready_feat_requests_rejects_non_proposed_status(self):
        """Test filter_ready_feat_requests rejects issues with non-Proposed status."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "Backlog"},  # Not "Proposed"
            },
            {
                "content": {
                    "number": 43,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "Done"},
            },
            {
                "content": {
                    "number": 44,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "In Progress"},
            },
        ]

        ready = filter_ready_feat_requests(items)

        assert ready == []

    def test_filter_ready_feat_requests_rejects_already_planned(self):
        """Test filter_ready_feat_requests rejects issues that already have agentize:plan."""
        items = [
            {
                "content": {
                    "number": 43,
                    "labels": {
                        "nodes": [{"name": "agentize:dev-req"}, {"name": "agentize:plan"}]
                    },
                },
                "fieldValueByName": {"name": "Proposed"},
            },
        ]

        ready = filter_ready_feat_requests(items)

        assert ready == []

    def test_filter_ready_feat_requests_debug_output(self, capsys):
        """Test filter_ready_feat_requests debug output contains expected messages."""
        items = [
            {
                "content": {
                    "number": 42,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 43,
                    "labels": {
                        "nodes": [{"name": "agentize:dev-req"}, {"name": "agentize:plan"}]
                    },
                },
                "fieldValueByName": {"name": "Proposed"},
            },
            {
                "content": {
                    "number": 44,
                    "labels": {"nodes": [{"name": "agentize:dev-req"}]},
                },
                "fieldValueByName": {"name": "Backlog"},
            },
        ]

        with patch("agentize.server.github._is_debug_enabled", return_value=True):
            filter_ready_feat_requests(items)

        captured = capsys.readouterr()
        debug_output = captured.err

        assert "filter_ready_feat_requests" in debug_output
        assert "already has agentize:plan" in debug_output
        assert "status != Proposed" in debug_output
