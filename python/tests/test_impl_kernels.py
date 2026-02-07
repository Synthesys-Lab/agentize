"""Tests for kernel functions in the impl workflow."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from agentize.workflow.impl.checkpoint import ImplState, create_initial_state
from agentize.workflow.impl.impl import ImplError
from agentize.workflow.impl.kernels import (
    _append_closes_line,
    _current_branch,
    _detect_base_branch,
    _detect_push_remote,
    _iteration_section,
    _parse_completion_marker,
    _parse_quality_score,
    _read_optional,
    _section,
    _shell_cmd,
)


class TestParseQualityScore:
    """Tests for _parse_quality_score function."""

    def test_parses_score_pattern(self):
        """Test parsing 'Score: 85/100' pattern."""
        output = "Some text\nScore: 85/100\nMore text"
        assert _parse_quality_score(output) == 85

    def test_parses_lowercase_score(self):
        """Test parsing lowercase 'score: 75/100'."""
        output = "score: 75/100"
        assert _parse_quality_score(output) == 75

    def test_parses_quality_pattern(self):
        """Test parsing 'Quality: 80' pattern."""
        output = "Quality: 80"
        assert _parse_quality_score(output) == 80

    def test_parses_quality_with_slash(self):
        """Test parsing 'Quality: 90/100' pattern."""
        output = "Quality: 90/100"
        assert _parse_quality_score(output) == 90

    def test_parses_rating_pattern(self):
        """Test parsing 'Rating: 8.5/10' pattern."""
        output = "Rating: 8.5/10"
        assert _parse_quality_score(output) == 85

    def test_parses_rating_whole_number(self):
        """Test parsing 'Rating: 7/10' pattern."""
        output = "Rating: 7/10"
        assert _parse_quality_score(output) == 70

    def test_returns_default_when_no_score(self):
        """Test returning default 50 when no score found."""
        output = "Some text without any score"
        assert _parse_quality_score(output) == 50

    def test_clamps_to_100(self):
        """Test that scores above 100 are clamped."""
        output = "Score: 150/100"
        assert _parse_quality_score(output) == 100

    def test_clamps_to_0(self):
        """Test that negative scores are clamped to 0."""
        output = "Score: -10/100"
        assert _parse_quality_score(output) == 0


class TestParseCompletionMarker:
    """Tests for _parse_completion_marker function."""

    def test_detects_completion_marker(self, tmp_path: Path):
        """Test detecting 'Issue N resolved' in file."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("PR Title\n\nIssue 42 resolved")
        assert _parse_completion_marker(finalize_file, 42) is True

    def test_detects_different_issue_number(self, tmp_path: Path):
        """Test that different issue number is not detected."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("Issue 42 resolved")
        assert _parse_completion_marker(finalize_file, 43) is False

    def test_returns_false_for_missing_file(self, tmp_path: Path):
        """Test returning False when file doesn't exist."""
        finalize_file = tmp_path / "nonexistent.txt"
        assert _parse_completion_marker(finalize_file, 42) is False

    def test_returns_false_without_marker(self, tmp_path: Path):
        """Test returning False when marker not present."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("Some content without marker")
        assert _parse_completion_marker(finalize_file, 42) is False


class TestReadOptional:
    """Tests for _read_optional function."""

    def test_reads_existing_file(self, tmp_path: Path):
        """Test reading content from existing file."""
        test_file = tmp_path / "test.txt"
        test_file.write_text("Hello World")
        assert _read_optional(test_file) == "Hello World"

    def test_returns_none_for_missing_file(self, tmp_path: Path):
        """Test returning None for missing file."""
        test_file = tmp_path / "nonexistent.txt"
        assert _read_optional(test_file) is None

    def test_returns_none_for_empty_file(self, tmp_path: Path):
        """Test returning None for empty file."""
        test_file = tmp_path / "empty.txt"
        test_file.write_text("")
        assert _read_optional(test_file) is None

    def test_returns_none_for_whitespace_only(self, tmp_path: Path):
        """Test returning None for whitespace-only file."""
        test_file = tmp_path / "whitespace.txt"
        test_file.write_text("   \n\t  ")
        assert _read_optional(test_file) is None

    def test_returns_none_for_directory(self, tmp_path: Path):
        """Test returning None for directory path."""
        assert _read_optional(tmp_path) is None


class TestShellCmd:
    """Tests for _shell_cmd function."""

    def test_joins_simple_parts(self):
        """Test joining simple command parts."""
        parts = ["git", "add", "file.txt"]
        assert _shell_cmd(parts) == "git add file.txt"

    def test_quotes_parts_with_spaces(self):
        """Test quoting parts containing spaces."""
        parts = ["git", "commit", "-m", "message with spaces"]
        assert _shell_cmd(parts) == "git commit -m 'message with spaces'"

    def test_handles_path_objects(self, tmp_path: Path):
        """Test handling Path objects."""
        parts = ["cat", tmp_path / "file.txt"]
        assert _shell_cmd(parts) == f"cat {tmp_path / 'file.txt'}"

    def test_handles_empty_list(self):
        """Test handling empty list."""
        assert _shell_cmd([]) == ""


class TestIterationSection:
    """Tests for _iteration_section function."""

    def test_generates_iteration_section(self):
        """Test generating iteration section text."""
        result = _iteration_section(3)
        assert "Current iteration: 3" in result
        assert ".tmp/commit-report-iter-3.txt" in result

    def test_returns_empty_for_none(self):
        """Test returning empty string for None."""
        assert _iteration_section(None) == ""


class TestSection:
    """Tests for _section function."""

    def test_generates_section_with_content(self):
        """Test generating section with content."""
        result = _section("Title", "Some content")
        assert "---" in result
        assert "Title" in result
        assert "Some content" in result

    def test_returns_empty_for_none_content(self):
        """Test returning empty string for None content."""
        assert _section("Title", None) == ""

    def test_returns_empty_for_empty_content(self):
        """Test returning empty string for empty content."""
        assert _section("Title", "") == ""

    def test_strips_trailing_whitespace(self):
        """Test that excessive trailing whitespace is stripped."""
        result = _section("Title", "Content\n\n")
        # Result should have exactly one trailing newline
        assert result.endswith("\n")
        assert not result.endswith("\n\n")


class TestDetectPushRemote:
    """Tests for _detect_push_remote function."""

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_prefers_upstream(self, mock_run):
        """Test that 'upstream' is preferred over 'origin'."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "origin\nupstream\n"
        mock_run.return_value = mock_result

        result = _detect_push_remote(Path("/tmp"))
        assert result == "upstream"

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_falls_back_to_origin(self, mock_run):
        """Test falling back to 'origin' when no upstream."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "origin\n"
        mock_run.return_value = mock_result

        result = _detect_push_remote(Path("/tmp"))
        assert result == "origin"

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_raises_error_for_no_remotes(self, mock_run):
        """Test raising error when no remotes found."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "\n"
        mock_run.return_value = mock_result

        with pytest.raises(ImplError, match="No remote found"):
            _detect_push_remote(Path("/tmp"))


class TestDetectBaseBranch:
    """Tests for _detect_base_branch function."""

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_prefers_master(self, mock_run):
        """Test that 'master' is preferred over 'main'."""
        def side_effect(cmd, **kwargs):
            result = MagicMock()
            if "master" in cmd:
                result.returncode = 0
            else:
                result.returncode = 1
            return result

        mock_run.side_effect = side_effect

        result = _detect_base_branch(Path("/tmp"), "origin")
        assert result == "master"

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_falls_back_to_main(self, mock_run):
        """Test falling back to 'main' when no master."""
        def side_effect(cmd, **kwargs):
            result = MagicMock()
            if "master" in cmd:
                result.returncode = 1
            else:
                result.returncode = 0
            return result

        mock_run.side_effect = side_effect

        result = _detect_base_branch(Path("/tmp"), "origin")
        assert result == "main"

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_raises_error_for_no_base_branch(self, mock_run):
        """Test raising error when no base branch found."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_run.return_value = mock_result

        with pytest.raises(ImplError, match="No default branch found"):
            _detect_base_branch(Path("/tmp"), "origin")


class TestCurrentBranch:
    """Tests for _current_branch function."""

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_returns_branch_name(self, mock_run):
        """Test returning current branch name."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "feature-branch\n"
        mock_run.return_value = mock_result

        result = _current_branch(Path("/tmp"))
        assert result == "feature-branch"

    @patch("agentize.workflow.impl.kernels.run_shell_function")
    def test_raises_error_on_failure(self, mock_run):
        """Test raising error when git command fails."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_run.return_value = mock_result

        with pytest.raises(ImplError, match="Failed to determine current branch"):
            _current_branch(Path("/tmp"))


class TestAppendClosesLine:
    """Tests for _append_closes_line function."""

    def test_appends_closes_line(self, tmp_path: Path):
        """Test appending closes line to file."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("PR Title\n\nDescription")

        _append_closes_line(finalize_file, 42)

        content = finalize_file.read_text()
        assert "Closes #42" in content

    def test_skips_if_already_present(self, tmp_path: Path):
        """Test skipping if closes line already present."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("PR Title\n\nDescription\nCloses #42\n")

        _append_closes_line(finalize_file, 42)

        content = finalize_file.read_text()
        assert content.count("Closes #42") == 1

    def test_handles_case_insensitive_match(self, tmp_path: Path):
        """Test handling case insensitive match."""
        finalize_file = tmp_path / "finalize.txt"
        finalize_file.write_text("PR Title\n\ncloses #42")

        _append_closes_line(finalize_file, 42)

        content = finalize_file.read_text()
        # Should not add another closes line
        assert content.count("closes") == 1


class TestKernelIntegration:
    """Integration-style tests for kernel functions."""

    def test_state_round_trip_with_kernels(self, tmp_path: Path):
        """Test that state can be used with kernel functions."""
        state = create_initial_state(42, tmp_path)

        # Verify state can be accessed by kernel helpers
        assert state.issue_no == 42
        assert state.current_stage == "impl"

        # Test file operations work with state paths
        tmp_dir = tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()
        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Score: 85/100")

        score = _parse_quality_score(output_file.read_text())
        assert score == 85
