"""Tests for impl FSM scaffold modules (state, transition, orchestrator)."""

from pathlib import Path
from types import SimpleNamespace

import pytest

from agentize.workflow.impl.checkpoint import create_initial_state
from agentize.workflow.impl.kernels import (
    KERNELS,
    impl_stage_kernel,
    pr_stage_kernel,
    rebase_stage_kernel,
    run_parse_gate,
    review_stage_kernel,
)
from agentize.workflow.impl.orchestrator import run_fsm_orchestrator
from agentize.workflow.impl.state import (
    EVENT_FATAL,
    EVENT_IMPL_DONE,
    EVENT_IMPL_NOT_DONE,
    EVENT_PR_PASS,
    EVENT_REVIEW_PASS,
    STAGE_FATAL,
    STAGE_FINISH,
    STAGE_IMPL,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_REVIEW,
    StageResult,
    WorkflowContext,
)
from agentize.workflow.impl.transition import (
    TRANSITIONS,
    TransitionError,
    next_stage,
    validate_transition_table,
)


class TestWorkflowContext:
    """Tests for state context helpers."""

    def test_bump_attempt_uses_current_stage(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        assert context.bump_attempt() == 1
        assert context.bump_attempt() == 2
        assert context.attempts[STAGE_IMPL] == 2

    def test_apply_stage_result_merges_payload_artifacts_feedback(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        result = StageResult(
            event=EVENT_IMPL_NOT_DONE,
            payload={
                "k": "v",
                "review_feedback": "review note",
                "parse_feedback": "parse note",
                "ci_feedback": "ci note",
            },
            artifacts=[".tmp/a.json"],
        )

        context.apply_stage_result(result)

        assert context.data["k"] == "v"
        assert context.artifacts == [".tmp/a.json"]
        assert context.review_feedback == "review note"
        assert context.parse_feedback == "parse note"
        assert context.ci_feedback == "ci note"


class TestTransitions:
    """Tests for transition table and transition validation."""

    def test_next_stage_resolves_expected_edges(self):
        assert next_stage(STAGE_IMPL, EVENT_IMPL_NOT_DONE) == STAGE_IMPL
        assert next_stage(STAGE_IMPL, EVENT_IMPL_DONE) == STAGE_REVIEW
        assert next_stage(STAGE_REVIEW, EVENT_REVIEW_PASS) == STAGE_PR
        assert next_stage(STAGE_PR, EVENT_PR_PASS) == STAGE_FINISH

    def test_next_stage_raises_on_unknown_stage(self):
        with pytest.raises(TransitionError, match="Unknown stage"):
            next_stage("unknown", EVENT_IMPL_DONE)  # type: ignore[arg-type]

    def test_next_stage_raises_on_unknown_event(self):
        with pytest.raises(TransitionError, match="Unknown event"):
            next_stage(STAGE_IMPL, "unknown")  # type: ignore[arg-type]

    def test_next_stage_raises_on_missing_mapping(self):
        with pytest.raises(TransitionError, match="Missing transition"):
            next_stage(STAGE_REVIEW, EVENT_IMPL_DONE)

    def test_validate_transition_table_passes_default_table(self):
        validate_transition_table()

    def test_validate_transition_table_raises_when_required_edge_missing(self):
        table = dict(TRANSITIONS)
        table.pop((STAGE_IMPL, EVENT_IMPL_DONE))
        with pytest.raises(TransitionError, match="Missing required transition"):
            validate_transition_table(table)


class TestOrchestrator:
    """Tests for orchestrator behavior."""

    def test_run_fsm_orchestrator_reaches_finish(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        logs: list[str] = []
        first_impl_attempt = {"seen": False}

        def impl_kernel(ctx: WorkflowContext) -> StageResult:
            if first_impl_attempt["seen"]:
                return StageResult(event=EVENT_IMPL_DONE, reason="ready")
            first_impl_attempt["seen"] = True
            return StageResult(event=EVENT_IMPL_NOT_DONE, reason="iterate")

        def review_kernel(ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_REVIEW_PASS, reason="review ok")

        def pr_kernel(ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_PR_PASS, reason="pr ok")

        kernels = {
            STAGE_IMPL: impl_kernel,
            STAGE_REVIEW: review_kernel,
            STAGE_PR: pr_kernel,
        }

        result = run_fsm_orchestrator(
            context,
            kernels=kernels,
            logger=logs.append,
            max_steps=10,
        )

        assert result.current_stage == STAGE_FINISH
        assert result.final_status == "finish"
        assert result.attempts[STAGE_IMPL] == 2
        assert any("stage=impl event=impl_not_done" in line for line in logs)
        assert any("stage=impl event=impl_done" in line for line in logs)
        assert any("stage=review event=review_pass" in line for line in logs)
        assert any("stage=pr event=pr_pass" in line for line in logs)

    def test_run_fsm_orchestrator_marks_fatal_on_missing_kernel(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        result = run_fsm_orchestrator(context, kernels={}, logger=lambda _msg: None)
        assert result.current_stage == STAGE_FATAL
        assert result.final_status == "fatal"
        assert "No kernel for stage" in result.fatal_reason

    def test_run_fsm_orchestrator_marks_fatal_on_invalid_event(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")

        def impl_kernel(_ctx: WorkflowContext) -> StageResult:
            return StageResult(event="unknown", reason="bad event")  # type: ignore[arg-type]

        logs: list[str] = []
        result = run_fsm_orchestrator(
            context,
            kernels={STAGE_IMPL: impl_kernel},
            logger=logs.append,
        )
        assert result.current_stage == STAGE_FATAL
        assert result.final_status == "fatal"
        assert "Unknown event" in result.fatal_reason
        assert any("stage=fatal event=fatal" in line for line in logs)

    def test_run_fsm_orchestrator_respects_max_steps(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")

        def impl_kernel(_ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_IMPL_NOT_DONE, reason="loop")

        result = run_fsm_orchestrator(
            context,
            kernels={STAGE_IMPL: impl_kernel},
            logger=lambda _msg: None,
            max_steps=2,
        )
        assert result.current_stage == STAGE_FATAL
        assert result.final_status == "fatal"
        assert "Max FSM steps exceeded" in result.fatal_reason


class TestKernelRegistry:
    """Tests for FSM kernel registry scaffold."""

    def test_registry_has_expected_stage_handlers(self):
        assert KERNELS[STAGE_IMPL] is impl_stage_kernel
        assert KERNELS[STAGE_REVIEW] is review_stage_kernel
        assert KERNELS[STAGE_PR] is pr_stage_kernel
        assert KERNELS[STAGE_REBASE] is rebase_stage_kernel

    def test_placeholder_kernels_return_fatal_event(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        for kernel in (impl_stage_kernel, review_stage_kernel, pr_stage_kernel, rebase_stage_kernel):
            result = kernel(context)
            assert result.event == EVENT_FATAL
            assert "Kernel not configured" in (result.reason or "")


class TestParseGate:
    """Tests for deterministic parse gate behavior."""

    def test_run_parse_gate_skips_when_no_changes(self, tmp_path: Path):
        state = create_initial_state(857, tmp_path)

        passed, feedback, report_path = run_parse_gate(state, files_changed=False)

        assert passed is True
        assert "no changed Python files" in feedback
        assert report_path.exists()
        assert '"pass": true' in report_path.read_text().lower()

    def test_run_parse_gate_passes_when_compile_succeeds(self, tmp_path: Path, monkeypatch):
        state = create_initial_state(857, tmp_path)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels._latest_commit_python_files",
            lambda _worktree: ["python/agentize/workflow/impl/state.py"],
        )
        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.run_shell_function",
            lambda *_args, **_kwargs: SimpleNamespace(returncode=0, stdout="", stderr=""),
        )

        passed, feedback, report_path = run_parse_gate(state, files_changed=True)

        assert passed is True
        assert "Parse gate passed" in feedback
        report = report_path.read_text()
        assert '"pass": true' in report.lower()
        assert '"failed_files": []' in report

    def test_run_parse_gate_fails_when_compile_fails(self, tmp_path: Path, monkeypatch):
        state = create_initial_state(857, tmp_path)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels._latest_commit_python_files",
            lambda _worktree: ["broken.py"],
        )
        stderr = 'File "broken.py", line 1\n    def x(:\n          ^\nSyntaxError: invalid syntax'
        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.run_shell_function",
            lambda *_args, **_kwargs: SimpleNamespace(returncode=1, stdout="", stderr=stderr),
        )

        passed, feedback, report_path = run_parse_gate(state, files_changed=True)

        assert passed is False
        assert "Parse gate failed" in feedback
        report = report_path.read_text()
        assert '"pass": false' in report.lower()
        assert '"failed_files": [' in report
        assert '"broken.py"' in report
