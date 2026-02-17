"""Tests for impl FSM modules (state, transition, orchestrator, stage kernels)."""

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
    simp_stage_kernel,
)
from agentize.workflow.impl.orchestrator import run_fsm_orchestrator
from agentize.workflow.impl.state import (
    EVENT_FATAL,
    EVENT_IMPL_DONE,
    EVENT_IMPL_NOT_DONE,
    EVENT_PARSE_FAIL,
    EVENT_PR_FAIL_FIXABLE,
    EVENT_PR_FAIL_NEED_REBASE,
    EVENT_PR_PASS,
    EVENT_REBASE_CONFLICT,
    EVENT_REBASE_OK,
    EVENT_REVIEW_FAIL,
    EVENT_REVIEW_PASS,
    EVENT_SIMP_FAIL,
    EVENT_SIMP_PASS,
    STAGE_FATAL,
    STAGE_FINISH,
    STAGE_IMPL,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_REVIEW,
    STAGE_SIMP,
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
        assert next_stage(STAGE_REVIEW, EVENT_REVIEW_PASS) == STAGE_SIMP
        assert next_stage(STAGE_SIMP, EVENT_SIMP_PASS) == STAGE_PR
        assert next_stage(STAGE_SIMP, EVENT_SIMP_FAIL) == STAGE_IMPL
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

        def simp_kernel(ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_SIMP_PASS, reason="simp ok")

        def pr_kernel(ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_PR_PASS, reason="pr ok")

        kernels = {
            STAGE_IMPL: impl_kernel,
            STAGE_REVIEW: review_kernel,
            STAGE_SIMP: simp_kernel,
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
        assert any("stage=simp event=simp_pass" in line for line in logs)
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
    """Tests for FSM kernel registry."""

    def test_registry_has_expected_stage_handlers(self):
        assert KERNELS[STAGE_IMPL] is impl_stage_kernel
        assert KERNELS[STAGE_REVIEW] is review_stage_kernel
        assert KERNELS[STAGE_SIMP] is simp_stage_kernel
        assert KERNELS[STAGE_PR] is pr_stage_kernel
        assert KERNELS[STAGE_REBASE] is rebase_stage_kernel


class TestPreStepHook:
    """Tests for pre_step_hook parameter on run_fsm_orchestrator."""

    def test_pre_step_hook_called_before_each_dispatch(self):
        context = WorkflowContext(plan="p", upstream_instruction="u")
        hook_calls: list[str] = []
        call_count = {"n": 0}

        def hook(ctx: WorkflowContext) -> None:
            hook_calls.append(ctx.current_stage)

        def impl_kernel(_ctx: WorkflowContext) -> StageResult:
            call_count["n"] += 1
            if call_count["n"] >= 2:
                return StageResult(event=EVENT_IMPL_DONE, reason="done")
            return StageResult(event=EVENT_IMPL_NOT_DONE, reason="iterate")

        def review_kernel(_ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_REVIEW_PASS, reason="ok")

        def simp_kernel(_ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_SIMP_PASS, reason="ok")

        def pr_kernel(_ctx: WorkflowContext) -> StageResult:
            return StageResult(event=EVENT_PR_PASS, reason="ok")

        kernels = {
            STAGE_IMPL: impl_kernel,
            STAGE_REVIEW: review_kernel,
            STAGE_SIMP: simp_kernel,
            STAGE_PR: pr_kernel,
        }

        run_fsm_orchestrator(
            context,
            kernels=kernels,
            logger=lambda _: None,
            pre_step_hook=hook,
        )

        # Hook should be called 5 times: 2x impl, 1x review, 1x simp, 1x pr
        assert len(hook_calls) == 5
        assert hook_calls[0] == STAGE_IMPL
        assert hook_calls[1] == STAGE_IMPL
        assert hook_calls[2] == STAGE_REVIEW
        assert hook_calls[3] == STAGE_SIMP
        assert hook_calls[4] == STAGE_PR


def _make_impl_context(tmp_path: Path, **overrides) -> WorkflowContext:
    """Helper to build a WorkflowContext with standard impl_state and data."""
    state = create_initial_state(857, tmp_path)
    data = {
        "impl_state": state,
        "session": None,
        "template_path": Path("/dev/null"),
        "impl_provider": "test",
        "impl_model": "test-model",
        "review_provider": "test",
        "review_model": "test-model",
        "yolo": False,
        "enable_review": False,
        "max_iterations": 10,
        "max_reviews": 8,
        "push_remote": "origin",
        "base_branch": "main",
        "checkpoint_path": tmp_path / "checkpoint.json",
        "parse_fail_streak": 0,
        "review_fail_streak": 0,
        "last_review_score": None,
        "retry_context": None,
        "review_attempts": 0,
        "enable_simp": False,
        "simp_attempts": 0,
        "max_simps": 3,
        "pr_attempts": 0,
        "rebase_attempts": 0,
    }
    data.update(overrides)
    return WorkflowContext(plan="", upstream_instruction="", data=data)


class TestImplStageKernel:
    """Tests for impl_stage_kernel."""

    def test_completion_and_parse_pass_returns_impl_done(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.impl_kernel",
            lambda state, session, **kw: (85, "done", {"completion_found": True, "files_changed": True}),
        )
        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.run_parse_gate",
            lambda state, files_changed: (True, "Parse ok", tmp_path / "parse.json"),
        )

        result = impl_stage_kernel(context)
        assert result.event == EVENT_IMPL_DONE

    def test_no_completion_returns_impl_not_done(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path)
        state = context.data["impl_state"]
        initial_iter = state.iteration

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.impl_kernel",
            lambda state, session, **kw: (50, "wip", {"completion_found": False, "files_changed": False}),
        )

        result = impl_stage_kernel(context)
        assert result.event == EVENT_IMPL_NOT_DONE
        assert state.iteration == initial_iter + 1

    def test_completion_parse_fail_returns_parse_fail(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path)
        parse_report = tmp_path / ".tmp" / "parse.json"
        parse_report.parent.mkdir(parents=True, exist_ok=True)
        parse_report.write_text('{"pass": false}')

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.impl_kernel",
            lambda state, session, **kw: (80, "done", {"completion_found": True, "files_changed": True}),
        )
        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.run_parse_gate",
            lambda state, files_changed: (False, "Parse failed", parse_report),
        )

        result = impl_stage_kernel(context)
        assert result.event == EVENT_PARSE_FAIL
        assert context.data["parse_fail_streak"] == 1

    def test_parse_fail_streak_3_returns_fatal(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, parse_fail_streak=2)
        parse_report = tmp_path / ".tmp" / "parse.json"
        parse_report.parent.mkdir(parents=True, exist_ok=True)
        parse_report.write_text('{"pass": false}')

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.impl_kernel",
            lambda state, session, **kw: (80, "done", {"completion_found": True, "files_changed": True}),
        )
        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.run_parse_gate",
            lambda state, files_changed: (False, "Parse failed", parse_report),
        )

        result = impl_stage_kernel(context)
        assert result.event == EVENT_FATAL
        assert "parse" in result.reason.lower()

    def test_max_iterations_returns_fatal(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, max_iterations=5)
        context.data["impl_state"].iteration = 6

        result = impl_stage_kernel(context)
        assert result.event == EVENT_FATAL
        assert "Max iteration" in result.reason


class TestReviewStageKernel:
    """Tests for review_stage_kernel."""

    def test_review_disabled_returns_review_pass(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, enable_review=False)

        result = review_stage_kernel(context)
        assert result.event == EVENT_REVIEW_PASS
        assert "disabled" in result.reason

    def test_review_passes_returns_review_pass(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, enable_review=True)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.review_kernel",
            lambda state, session, **kw: (True, "All good", 92),
        )

        result = review_stage_kernel(context)
        assert result.event == EVENT_REVIEW_PASS
        assert "92" in result.reason

    def test_review_fails_returns_review_fail(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, enable_review=True)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.review_kernel",
            lambda state, session, **kw: (False, "Needs work", 60),
        )

        result = review_stage_kernel(context)
        assert result.event == EVENT_REVIEW_FAIL
        assert context.data.get("retry_context") is not None

    def test_convergence_4x_non_improving_returns_fatal(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(
            tmp_path,
            enable_review=True,
            review_fail_streak=3,
            last_review_score=70,
        )

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.review_kernel",
            lambda state, session, **kw: (False, "Still bad", 60),
        )

        result = review_stage_kernel(context)
        assert result.event == EVENT_FATAL
        assert "no improvement" in result.reason.lower()

    def test_max_reviews_returns_review_pass(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, enable_review=True, review_attempts=8, max_reviews=8)

        result = review_stage_kernel(context)
        assert result.event == EVENT_REVIEW_PASS
        assert "max" in result.reason.lower()


class TestSimpStageKernel:
    """Tests for simp_stage_kernel."""

    def test_simp_disabled_returns_simp_pass(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, enable_simp=False)

        result = simp_stage_kernel(context)
        assert result.event == EVENT_SIMP_PASS
        assert "disabled" in result.reason

    def test_simp_passes_returns_simp_pass(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, enable_simp=True)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.simp_kernel",
            lambda state, session, **kw: (True, "Simplification completed successfully"),
        )

        result = simp_stage_kernel(context)
        assert result.event == EVENT_SIMP_PASS

    def test_simp_fails_returns_simp_fail(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, enable_simp=True)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.simp_kernel",
            lambda state, session, **kw: (False, "Code can be simplified"),
        )

        result = simp_stage_kernel(context)
        assert result.event == EVENT_SIMP_FAIL
        assert context.data.get("retry_context") is not None

    def test_max_simps_returns_simp_pass(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, enable_simp=True, simp_attempts=3, max_simps=3)

        result = simp_stage_kernel(context)
        assert result.event == EVENT_SIMP_PASS
        assert "max" in result.reason.lower()

    def test_simp_fail_increments_iteration(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path, enable_simp=True)
        state = context.data["impl_state"]
        initial_iter = state.iteration

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.simp_kernel",
            lambda state, session, **kw: (False, "Needs simplification"),
        )

        simp_stage_kernel(context)
        assert state.iteration == initial_iter + 1


class TestPrStageKernel:
    """Tests for pr_stage_kernel."""

    def test_pr_pass_passthrough(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.pr_kernel",
            lambda state, session, **kw: (EVENT_PR_PASS, "PR created", "123", "http://pr", tmp_path / "pr.json"),
        )

        result = pr_stage_kernel(context)
        assert result.event == EVENT_PR_PASS
        assert context.data["impl_state"].pr_number == "123"

    def test_pr_fail_fixable_sets_retry_context(self, tmp_path: Path, monkeypatch):
        pr_report = tmp_path / "pr.json"
        pr_report.write_text('{"event": "pr_fail_fixable"}')

        context = _make_impl_context(tmp_path)

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.pr_kernel",
            lambda state, session, **kw: (EVENT_PR_FAIL_FIXABLE, "Title invalid", None, None, pr_report),
        )

        result = pr_stage_kernel(context)
        assert result.event == EVENT_PR_FAIL_FIXABLE
        assert context.data.get("retry_context") is not None

    def test_pr_attempts_7_returns_fatal(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, pr_attempts=6)

        result = pr_stage_kernel(context)
        assert result.event == EVENT_FATAL
        assert "PR retry limit" in result.reason


class TestRebaseStageKernel:
    """Tests for rebase_stage_kernel."""

    def test_rebase_ok_passthrough(self, tmp_path: Path, monkeypatch):
        context = _make_impl_context(tmp_path)
        state = context.data["impl_state"]
        initial_iter = state.iteration

        monkeypatch.setattr(
            "agentize.workflow.impl.kernels.rebase_kernel",
            lambda state, **kw: (EVENT_REBASE_OK, "Rebased", tmp_path / "rebase.json"),
        )

        result = rebase_stage_kernel(context)
        assert result.event == EVENT_REBASE_OK
        assert state.iteration == initial_iter + 1

    def test_rebase_attempts_4_returns_fatal(self, tmp_path: Path):
        context = _make_impl_context(tmp_path, rebase_attempts=3)

        result = rebase_stage_kernel(context)
        assert result.event == EVENT_FATAL
        assert "rebase retry limit" in result.reason.lower()


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
