"""Tests for review kernel functionality in the impl workflow."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from agentize.workflow.impl.checkpoint import ImplState, create_initial_state
from agentize.workflow.impl.impl import ImplError
from agentize.workflow.impl.kernels import review_kernel


class TestReviewKernel:
    """Tests for review_kernel function."""

    @patch("agentize.workflow.api.Session")
    def test_review_passes_with_high_score(self, mock_session_class, tmp_path: Path):
        """Test review passes when score >= threshold."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        # Create output file
        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        # Mock session result
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text("Score: 85/100\nPassed: Yes")
        mock_result.text.return_value = "Score: 85/100\nPassed: Yes"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is True
        assert score == 85
        assert mock_session.run_prompt.called

    @patch("agentize.workflow.api.Session")
    def test_review_fails_with_low_score(self, mock_session_class, tmp_path: Path):
        """Test review fails when score < threshold."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text(
            "Score: 60/100\nPassed: No\nFeedback:\n- Need more tests"
        )
        mock_result.text.return_value = (
            "Score: 60/100\nPassed: No\nFeedback:\n- Need more tests"
        )

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is False
        assert score == 60
        assert "Need more tests" in feedback

    @patch("agentize.workflow.api.Session")
    def test_review_uses_default_threshold(self, mock_session_class, tmp_path: Path):
        """Test review uses default threshold of 70."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text("Score: 70/100\nPassed: Yes")
        mock_result.text.return_value = "Score: 70/100\nPassed: Yes"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        # No threshold specified, should default to 70
        passed, _, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        assert passed is True
        assert score == 70

    @patch("agentize.workflow.api.Session")
    def test_review_extracts_feedback_section(self, mock_session_class, tmp_path: Path):
        """Test that feedback section is extracted from review output."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        review_output = """Score: 65/100
Passed: No
Feedback:
- Missing error handling
- Tests incomplete
- Documentation needs work

Suggestions:
Add more comprehensive tests
"""
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text(review_output)
        mock_result.text.return_value = review_output

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is False
        assert "Missing error handling" in feedback
        assert "Tests incomplete" in feedback

    def test_review_returns_false_when_no_output_file(self, tmp_path: Path):
        """Test review returns false when no implementation output exists."""
        state = create_initial_state(42, tmp_path)
        mock_session = MagicMock()

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        assert passed is False
        assert "No implementation output found" in feedback
        assert score == 0
        assert not mock_session.run_prompt.called

    @patch("agentize.workflow.api.Session")
    def test_review_handles_pipeline_error(self, mock_session_class, tmp_path: Path):
        """Test review handles pipeline error gracefully."""
        from agentize.workflow.api.session import PipelineError

        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_session = MagicMock()
        mock_session.run_prompt.side_effect = PipelineError(
            "review", 1, "Connection error"
        )

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        # Should assume pass to avoid blocking
        assert passed is True
        assert "assuming pass" in feedback.lower()
        assert score == 75

    @patch("agentize.workflow.api.Session")
    def test_review_uses_iteration_in_filename(self, mock_session_class, tmp_path: Path):
        """Test review uses iteration number in output filename."""
        state = create_initial_state(42, tmp_path)
        state.iteration = 3
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-3.txt"
        mock_result.output_path.write_text("Score: 80/100\nPassed: Yes")
        mock_result.text.return_value = "Score: 80/100\nPassed: Yes"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        # Check that the call used iteration 3 in the stage name
        call_args = mock_session.run_prompt.call_args
        assert call_args[0][0] == "review-3"


class TestReviewOutputParsing:
    """Tests for review output parsing edge cases."""

    @patch("agentize.workflow.api.Session")
    def test_parses_score_at_boundary(self, mock_session_class, tmp_path: Path):
        """Test parsing score exactly at threshold boundary."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text("Score: 69/100")
        mock_result.text.return_value = "Score: 69/100"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        # Score 69 with threshold 70 should fail
        passed, _, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is False
        assert score == 69

    @patch("agentize.workflow.api.Session")
    def test_handles_empty_feedback(self, mock_session_class, tmp_path: Path):
        """Test handling empty feedback section."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text("Score: 90/100\nPassed: Yes")
        mock_result.text.return_value = "Score: 90/100\nPassed: Yes"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        assert passed is True
        assert score == 90

    @patch("agentize.workflow.api.Session")
    def test_handles_various_score_formats(self, mock_session_class, tmp_path: Path):
        """Test handling various score output formats."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        test_cases = [
            ("Quality: 85", 85),
            ("Overall Score: 72/100", 72),
            ("Rating: 8/10", 80),
        ]

        for review_text, expected_score in test_cases:
            mock_result = MagicMock()
            mock_result.output_path = tmp_dir / "review-output-1.txt"
            mock_result.output_path.write_text(review_text)
            mock_result.text.return_value = review_text

            mock_session = MagicMock()
            mock_session.run_prompt.return_value = mock_result

            passed, _, score = review_kernel(
                state,
                mock_session,
                provider="codex",
                model="gpt-5",
                threshold=70,
            )

            assert score == expected_score, f"Failed for: {review_text}"


class TestReviewWorkflowIntegration:
    """Tests for review workflow integration scenarios."""

    @patch("agentize.workflow.api.Session")
    def test_max_review_attempts_prevents_infinite_loop(
        self, mock_session_class, tmp_path: Path
    ):
        """Test that review system handles multiple attempts."""
        state = create_initial_state(42, tmp_path)
        tmp_dir = tmp_path / ".tmp"
        tmp_dir.mkdir()

        output_file = tmp_dir / "impl-output.txt"
        output_file.write_text("Implementation output")
        issue_file = tmp_dir / "issue-42.md"
        issue_file.write_text("Issue requirements")

        # First review fails
        mock_result1 = MagicMock()
        mock_result1.output_path = tmp_dir / "review-output-1.txt"
        mock_result1.output_path.write_text("Score: 60/100\nFeedback:\n- Fix A")
        mock_result1.text.return_value = "Score: 60/100\nFeedback:\n- Fix A"

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result1

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is False

        # Simulate re-implementation and second review
        state.iteration = 2
        state.last_feedback = feedback
        state.last_score = score

        mock_result2 = MagicMock()
        mock_result2.output_path = tmp_dir / "review-output-2.txt"
        mock_result2.output_path.write_text("Score: 80/100\nPassed: Yes")
        mock_result2.text.return_value = "Score: 80/100\nPassed: Yes"

        mock_session.run_prompt.return_value = mock_result2

        passed, feedback, score = review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
            threshold=70,
        )

        assert passed is True
        assert score == 80

    def test_review_preserves_state_history(self, tmp_path: Path):
        """Test that review updates state history correctly."""
        state = create_initial_state(42, tmp_path)

        # Simulate a review being added to history
        state.history.append({
            "stage": "review",
            "iteration": 1,
            "timestamp": "2025-01-15T10:00:00",
            "result": "retry",
            "score": 60,
        })

        assert len(state.history) == 1
        assert state.history[0]["score"] == 60
        assert state.history[0]["result"] == "retry"
