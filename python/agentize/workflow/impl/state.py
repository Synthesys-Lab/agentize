"""State contracts for the impl workflow finite-state orchestrator."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

STAGE_IMPL = "impl"
STAGE_REVIEW = "review"
STAGE_PR = "pr"
STAGE_REBASE = "rebase"
STAGE_FINISH = "finish"
STAGE_FATAL = "fatal"

Stage = Literal["impl", "review", "pr", "rebase", "finish", "fatal"]

EVENT_IMPL_DONE = "impl_done"
EVENT_IMPL_NOT_DONE = "impl_not_done"
EVENT_PARSE_FAIL = "parse_fail"
EVENT_REVIEW_PASS = "review_pass"
EVENT_REVIEW_FAIL = "review_fail"
EVENT_PR_PASS = "pr_pass"
EVENT_PR_FAIL_FIXABLE = "pr_fail_fixable"
EVENT_PR_FAIL_NEED_REBASE = "pr_fail_need_rebase"
EVENT_REBASE_OK = "rebase_ok"
EVENT_REBASE_CONFLICT = "rebase_conflict"
EVENT_FATAL = "fatal"

Event = Literal[
    "impl_done",
    "impl_not_done",
    "parse_fail",
    "review_pass",
    "review_fail",
    "pr_pass",
    "pr_fail_fixable",
    "pr_fail_need_rebase",
    "rebase_ok",
    "rebase_conflict",
    "fatal",
]

STAGES: tuple[Stage, ...] = (
    STAGE_IMPL,
    STAGE_REVIEW,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_FINISH,
    STAGE_FATAL,
)

TERMINAL_STAGES: tuple[Stage, ...] = (STAGE_FINISH, STAGE_FATAL)

EVENTS: tuple[Event, ...] = (
    EVENT_IMPL_DONE,
    EVENT_IMPL_NOT_DONE,
    EVENT_PARSE_FAIL,
    EVENT_REVIEW_PASS,
    EVENT_REVIEW_FAIL,
    EVENT_PR_PASS,
    EVENT_PR_FAIL_FIXABLE,
    EVENT_PR_FAIL_NEED_REBASE,
    EVENT_REBASE_OK,
    EVENT_REBASE_CONFLICT,
    EVENT_FATAL,
)


@dataclass(slots=True)
class StageResult:
    """Result produced by a single stage handler."""

    event: Event
    payload: dict[str, Any] = field(default_factory=dict)
    reason: str | None = None
    artifacts: list[str] = field(default_factory=list)
    metrics: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class WorkflowContext:
    """Runtime context for the explicit finite-state workflow."""

    plan: str
    upstream_instruction: str
    current_stage: Stage = STAGE_IMPL
    attempts: dict[str, int] = field(default_factory=dict)
    review_feedback: str = ""
    parse_feedback: str = ""
    ci_feedback: str = ""
    artifacts: list[str] = field(default_factory=list)
    final_status: str = "running"
    fatal_reason: str = ""
    data: dict[str, Any] = field(default_factory=dict)

    def bump_attempt(self, stage: Stage | str | None = None) -> int:
        """Increment and return current attempt counter for a stage."""
        stage_name = stage or self.current_stage
        current = self.attempts.get(stage_name, 0) + 1
        self.attempts[stage_name] = current
        return current

    def apply_stage_result(self, result: StageResult) -> None:
        """Merge stage output payload and artifacts back into context."""
        self.data.update(result.payload)
        self.artifacts.extend(result.artifacts)

        review_feedback = result.payload.get("review_feedback")
        if isinstance(review_feedback, str):
            self.review_feedback = review_feedback

        parse_feedback = result.payload.get("parse_feedback")
        if isinstance(parse_feedback, str):
            self.parse_feedback = parse_feedback

        ci_feedback = result.payload.get("ci_feedback")
        if isinstance(ci_feedback, str):
            self.ci_feedback = ci_feedback

