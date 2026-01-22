"""Tests for agentize.server session lookup helpers."""

import json
import pytest
from pathlib import Path

from agentize.server.__main__ import (
    _resolve_session_dir,
    _load_issue_index,
    _load_session_state,
    _get_session_state_for_issue,
    _remove_issue_index,
)


class TestResolveSessionDir:
    """Tests for _resolve_session_dir function."""

    def test_resolve_session_dir_uses_agentize_home(self, set_agentize_home):
        """Test _resolve_session_dir uses AGENTIZE_HOME."""
        result = _resolve_session_dir()
        assert str(result).endswith(".tmp/hooked-sessions")


class TestLoadIssueIndex:
    """Tests for _load_issue_index function."""

    def test_load_issue_index_returns_session_id(self, set_agentize_home):
        """Test _load_issue_index returns session_id when file exists."""
        tmp_path = set_agentize_home
        index_dir = tmp_path / ".tmp" / "hooked-sessions" / "by-issue"
        index_dir.mkdir(parents=True)

        index_data = {"session_id": "abc123", "workflow": "issue-to-impl"}
        (index_dir / "42.json").write_text(json.dumps(index_data))

        session_dir = _resolve_session_dir()
        session_id = _load_issue_index(42, session_dir)

        assert session_id == "abc123"

    def test_load_issue_index_returns_none_when_missing(self, set_agentize_home):
        """Test _load_issue_index returns None when file missing."""
        tmp_path = set_agentize_home
        index_dir = tmp_path / ".tmp" / "hooked-sessions" / "by-issue"
        index_dir.mkdir(parents=True)

        session_dir = _resolve_session_dir()
        session_id = _load_issue_index(999, session_dir)

        assert session_id is None


class TestLoadSessionState:
    """Tests for _load_session_state function."""

    def test_load_session_state_loads_json(self, set_agentize_home):
        """Test _load_session_state loads session JSON."""
        tmp_path = set_agentize_home
        session_dir = tmp_path / ".tmp" / "hooked-sessions"
        session_dir.mkdir(parents=True)

        state_data = {"workflow": "issue-to-impl", "state": "done", "issue_no": 42}
        (session_dir / "abc123.json").write_text(json.dumps(state_data))

        session_dir_path = _resolve_session_dir()
        state = _load_session_state("abc123", session_dir_path)

        assert state is not None
        assert state["state"] == "done"


class TestGetSessionStateForIssue:
    """Tests for _get_session_state_for_issue function."""

    def test_get_session_state_for_issue_combined_lookup(self, set_agentize_home):
        """Test _get_session_state_for_issue combines index and state lookup."""
        tmp_path = set_agentize_home
        session_dir = tmp_path / ".tmp" / "hooked-sessions"
        index_dir = session_dir / "by-issue"
        index_dir.mkdir(parents=True)

        # Create index file
        index_data = {"session_id": "abc123"}
        (index_dir / "42.json").write_text(json.dumps(index_data))

        # Create session state file
        state_data = {"workflow": "issue-to-impl", "state": "done", "issue_no": 42}
        (session_dir / "abc123.json").write_text(json.dumps(state_data))

        session_dir_path = _resolve_session_dir()
        state = _get_session_state_for_issue(42, session_dir_path)

        assert state is not None
        assert state["state"] == "done"

    def test_get_session_state_for_issue_returns_none_for_missing(
        self, set_agentize_home
    ):
        """Test _get_session_state_for_issue returns None for missing issue."""
        tmp_path = set_agentize_home
        session_dir = tmp_path / ".tmp" / "hooked-sessions"
        session_dir.mkdir(parents=True)

        session_dir_path = _resolve_session_dir()
        state = _get_session_state_for_issue(888, session_dir_path)

        assert state is None


class TestRemoveIssueIndex:
    """Tests for _remove_issue_index function."""

    def test_remove_issue_index_removes_file(self, set_agentize_home):
        """Test _remove_issue_index removes the index file."""
        tmp_path = set_agentize_home
        index_dir = tmp_path / ".tmp" / "hooked-sessions" / "by-issue"
        index_dir.mkdir(parents=True)

        index_file = index_dir / "42.json"
        index_file.write_text('{"session_id": "abc123"}')

        assert index_file.exists()

        session_dir = _resolve_session_dir()
        _remove_issue_index(42, session_dir)

        assert not index_file.exists()

    def test_remove_issue_index_no_error_when_missing(self, set_agentize_home):
        """Test _remove_issue_index doesn't error when file already missing."""
        tmp_path = set_agentize_home
        index_dir = tmp_path / ".tmp" / "hooked-sessions" / "by-issue"
        index_dir.mkdir(parents=True)

        session_dir = _resolve_session_dir()

        # Should not raise an error (missing_ok=True)
        _remove_issue_index(42, session_dir)
