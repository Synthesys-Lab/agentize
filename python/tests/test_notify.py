"""Tests for agentize.server Telegram notification helpers."""

import pytest

from agentize.server.__main__ import (
    _extract_repo_slug,
    _format_worker_assignment_message,
    _format_worker_completion_message,
)


class TestExtractRepoSlug:
    """Tests for _extract_repo_slug function."""

    def test_extract_repo_slug_https_without_git(self):
        """Test HTTPS URL without .git suffix."""
        result = _extract_repo_slug("https://github.com/org/repo")
        assert result == "org/repo"

    def test_extract_repo_slug_https_with_git(self):
        """Test HTTPS URL with .git suffix."""
        result = _extract_repo_slug("https://github.com/org/repo.git")
        assert result == "org/repo"

    def test_extract_repo_slug_ssh_format(self):
        """Test SSH format URL."""
        result = _extract_repo_slug("git@github.com:org/repo.git")
        assert result == "org/repo"

    def test_extract_repo_slug_invalid_url(self):
        """Test invalid URL returns None."""
        result = _extract_repo_slug("not-a-url")
        assert result is None

    def test_extract_repo_slug_empty_string(self):
        """Test empty string returns None."""
        result = _extract_repo_slug("")
        assert result is None


class TestFormatWorkerAssignmentMessage:
    """Tests for _format_worker_assignment_message function."""

    def test_html_escaping_script_tags(self):
        """Test HTML escaping in title for script tags."""
        msg = _format_worker_assignment_message(
            42, "<script>alert(1)</script>", 0, None
        )
        assert "&lt;script&gt;" in msg
        assert "<script>" not in msg

    def test_html_escaping_ampersand(self):
        """Test HTML escaping for ampersand."""
        msg = _format_worker_assignment_message(42, "A & B", 0, None)
        assert "&amp;" in msg
        # Check that raw & is not in HTML context (but might be in escaped form)
        # The message should have &amp; instead of raw &
        assert "A &amp; B" in msg or "A & B" not in msg.replace("&amp;", "")

    def test_includes_link_when_url_provided(self):
        """Test message includes href when URL provided."""
        msg = _format_worker_assignment_message(
            42, "Test Title", 1, "https://github.com/org/repo/issues/42"
        )
        assert 'href="https://github.com/org/repo/issues/42"' in msg

    def test_no_link_when_url_none(self):
        """Test message does not include href when URL is None."""
        msg = _format_worker_assignment_message(42, "Test Title", 1, None)
        assert "href=" not in msg
        assert "#42" in msg

    def test_includes_worker_id_and_issue_number(self):
        """Test message includes worker ID and issue number."""
        msg = _format_worker_assignment_message(123, "My Issue", 5, None)
        assert "#123" in msg
        assert "Worker: 5" in msg
        assert "My Issue" in msg


class TestFormatWorkerCompletionMessage:
    """Tests for _format_worker_completion_message function."""

    def test_basic_formatting(self):
        """Test basic completion message formatting."""
        msg = _format_worker_completion_message(42, 1, None)
        assert "#42" in msg
        assert "Worker: 1" in msg
        assert "Completed" in msg or "Complete" in msg

    def test_includes_link_when_url_provided(self):
        """Test completion message includes link when URL provided."""
        msg = _format_worker_completion_message(
            42, 1, "https://github.com/org/repo/issues/42"
        )
        assert 'href="https://github.com/org/repo/issues/42"' in msg

    def test_no_link_when_url_none(self):
        """Test completion message has no link when URL is None."""
        msg = _format_worker_completion_message(42, 1, None)
        assert "href=" not in msg

    def test_includes_pr_link_when_provided(self):
        """Test completion message includes both issue and PR links."""
        msg = _format_worker_completion_message(
            42,
            1,
            "https://github.com/org/repo/issues/42",
            pr_url="https://github.com/org/repo/pull/123",
        )
        assert 'href="https://github.com/org/repo/issues/42"' in msg
        assert 'href="https://github.com/org/repo/pull/123"' in msg
        assert "PR:" in msg or "Pull Request" in msg

    def test_pr_link_without_issue_url(self):
        """Test completion message with PR URL but no issue URL."""
        msg = _format_worker_completion_message(
            42, 1, None, pr_url="https://github.com/org/repo/pull/123"
        )
        assert "#42" in msg
        assert 'href="https://github.com/org/repo/pull/123"' in msg

    def test_no_pr_link_when_pr_url_none(self):
        """Test completion message without PR URL doesn't include PR link."""
        msg = _format_worker_completion_message(
            42, 1, "https://github.com/org/repo/issues/42", pr_url=None
        )
        assert 'href="https://github.com/org/repo/issues/42"' in msg
        assert "/pull/" not in msg
