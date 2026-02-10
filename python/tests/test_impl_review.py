"""Tests for review kernel functionality in the impl workflow."""

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

from agentize.workflow.impl.checkpoint import create_initial_state
from agentize.workflow.impl.kernels import review_kernel


def _prepare_review_inputs(tmp_path: Path, issue_no: int = 42):
    state = create_initial_state(issue_no, tmp_path)
    tmp_dir = tmp_path / ".tmp"
    tmp_dir.mkdir(exist_ok=True)
    (tmp_dir / "impl-output.txt").write_text("Implementation output")
    (tmp_dir / f"issue-{issue_no}.md").write_text("Issue requirements")
    return state, tmp_dir


class TestReviewKernel:
    """Tests for review_kernel function."""

    @patch("agentize.workflow.api.Session")
    def test_review_passes_with_structured_scores(self, mock_session_class, tmp_path: Path):
        state, tmp_dir = _prepare_review_inputs(tmp_path)

        review_payload = {
            "scores": {
                "faithful": 95,
                "style": 90,
                "docs": 88,
                "corner_cases": 86,
            },
            "overall_score": 92,
            "findings": ["Looks complete"],
            "suggestions": [],
        }
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text(json.dumps(review_payload))
        mock_result.text.return_value = json.dumps(review_payload)

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
        assert score == 92
        assert "Looks complete" in feedback

        report_path = tmp_dir / "review-iter-1.json"
        report = json.loads(report_path.read_text())
        assert report["pass"] is True
        assert report["scores"]["faithful"] == 95
        assert report["scores"]["style"] == 90
        assert report["scores"]["docs"] == 88
        assert report["scores"]["corner_cases"] == 86

    @patch("agentize.workflow.api.Session")
    def test_review_fails_when_threshold_dimensions_fail(self, mock_session_class, tmp_path: Path):
        state, tmp_dir = _prepare_review_inputs(tmp_path)

        review_payload = {
            "scores": {
                "faithful": 89,
                "style": 84,
                "docs": 90,
                "corner_cases": 83,
            },
            "overall_score": 93,
            "findings": ["Issues found"],
            "suggestions": ["Raise faithful and style scores"],
        }
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text(json.dumps(review_payload))
        mock_result.text.return_value = json.dumps(review_payload)

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
        assert score == 93
        assert "Raise faithful and style scores" in feedback

        report_path = tmp_dir / "review-iter-1.json"
        report = json.loads(report_path.read_text())
        assert report["pass"] is False
        assert report["scores"]["faithful"] == 89
        assert report["scores"]["style"] == 84

    @patch("agentize.workflow.api.Session")
    def test_review_writes_report_from_text_fallback(self, mock_session_class, tmp_path: Path):
        state, tmp_dir = _prepare_review_inputs(tmp_path)

        review_text = """Score: 69/100
Feedback:
- Missing error handling
- Tests incomplete
Suggestions:
- Add tests
"""
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-1.txt"
        mock_result.output_path.write_text(review_text)
        mock_result.text.return_value = review_text

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
        assert score == 69
        assert "Add tests" in feedback

        report_path = tmp_dir / "review-iter-1.json"
        report = json.loads(report_path.read_text())
        assert report["pass"] is False
        assert report["scores"]["faithful"] == 69
        assert report["scores"]["style"] == 69

    @patch("agentize.workflow.api.Session")
    def test_review_pipeline_error_returns_fail_and_report(self, mock_session_class, tmp_path: Path):
        from agentize.workflow.api.session import PipelineError

        state, tmp_dir = _prepare_review_inputs(tmp_path)

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

        assert passed is False
        assert score == 0
        assert "Review pipeline error" in feedback

        report_path = tmp_dir / "review-iter-1.json"
        report = json.loads(report_path.read_text())
        assert report["pass"] is False
        assert "Review pipeline error" in report["findings"][0]

    def test_review_returns_false_when_no_output_file(self, tmp_path: Path):
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

    @patch("agentize.workflow.api.Session")
    def test_review_uses_iteration_in_filename(self, mock_session_class, tmp_path: Path):
        state, tmp_dir = _prepare_review_inputs(tmp_path)
        state.iteration = 3

        review_payload = {
            "scores": {
                "faithful": 95,
                "style": 90,
                "docs": 88,
                "corner_cases": 86,
            },
            "overall_score": 91,
            "findings": [],
            "suggestions": [],
        }
        mock_result = MagicMock()
        mock_result.output_path = tmp_dir / "review-output-3.txt"
        mock_result.output_path.write_text(json.dumps(review_payload))
        mock_result.text.return_value = json.dumps(review_payload)

        mock_session = MagicMock()
        mock_session.run_prompt.return_value = mock_result

        review_kernel(
            state,
            mock_session,
            provider="codex",
            model="gpt-5",
        )

        call_args = mock_session.run_prompt.call_args
        assert call_args[0][0] == "review-3"
        assert (tmp_dir / "review-iter-3.json").exists()
