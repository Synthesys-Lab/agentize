"""Transition table and validation for impl workflow finite-state machine."""

from __future__ import annotations

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
    EVENTS,
    STAGE_FATAL,
    STAGE_FINISH,
    STAGE_IMPL,
    STAGE_PR,
    STAGE_REBASE,
    STAGE_REVIEW,
    STAGES,
    Event,
    Stage,
)


TransitionKey = tuple[Stage, Event]
TransitionTable = dict[TransitionKey, Stage]


TRANSITIONS: TransitionTable = {
    (STAGE_IMPL, EVENT_IMPL_NOT_DONE): STAGE_IMPL,
    (STAGE_IMPL, EVENT_PARSE_FAIL): STAGE_IMPL,
    (STAGE_IMPL, EVENT_IMPL_DONE): STAGE_REVIEW,
    (STAGE_IMPL, EVENT_FATAL): STAGE_FATAL,
    (STAGE_REVIEW, EVENT_REVIEW_PASS): STAGE_PR,
    (STAGE_REVIEW, EVENT_REVIEW_FAIL): STAGE_IMPL,
    (STAGE_REVIEW, EVENT_FATAL): STAGE_FATAL,
    (STAGE_PR, EVENT_PR_PASS): STAGE_FINISH,
    (STAGE_PR, EVENT_PR_FAIL_FIXABLE): STAGE_IMPL,
    (STAGE_PR, EVENT_PR_FAIL_NEED_REBASE): STAGE_REBASE,
    (STAGE_PR, EVENT_FATAL): STAGE_FATAL,
    (STAGE_REBASE, EVENT_REBASE_OK): STAGE_IMPL,
    (STAGE_REBASE, EVENT_REBASE_CONFLICT): STAGE_FATAL,
    (STAGE_REBASE, EVENT_FATAL): STAGE_FATAL,
    (STAGE_FINISH, EVENT_FATAL): STAGE_FATAL,
    (STAGE_FATAL, EVENT_FATAL): STAGE_FATAL,
}


class TransitionError(RuntimeError):
    """Raised when a transition lookup or configuration is invalid."""


def _assert_known_stage(stage: str) -> None:
    if stage not in STAGES:
        raise TransitionError(f"Unknown stage: {stage}")


def _assert_known_event(event: str) -> None:
    if event not in EVENTS:
        raise TransitionError(f"Unknown event: {event}")


def next_stage(stage: Stage, event: Event, *, table: TransitionTable | None = None) -> Stage:
    """Resolve next stage from current stage and emitted event."""
    transition_table = table or TRANSITIONS
    _assert_known_stage(stage)
    _assert_known_event(event)

    key = (stage, event)
    if key not in transition_table:
        raise TransitionError(f"Missing transition for stage={stage}, event={event}")
    return transition_table[key]


def validate_transition_table(table: TransitionTable | None = None) -> None:
    """Validate transition table wiring to fail fast on configuration mistakes."""
    transition_table = table or TRANSITIONS

    for (stage, event), target_stage in transition_table.items():
        _assert_known_stage(stage)
        _assert_known_event(event)
        _assert_known_stage(target_stage)

    required_pairs: tuple[TransitionKey, ...] = (
        (STAGE_IMPL, EVENT_IMPL_NOT_DONE),
        (STAGE_IMPL, EVENT_PARSE_FAIL),
        (STAGE_IMPL, EVENT_IMPL_DONE),
        (STAGE_REVIEW, EVENT_REVIEW_PASS),
        (STAGE_REVIEW, EVENT_REVIEW_FAIL),
        (STAGE_PR, EVENT_PR_PASS),
        (STAGE_PR, EVENT_PR_FAIL_FIXABLE),
        (STAGE_PR, EVENT_PR_FAIL_NEED_REBASE),
        (STAGE_REBASE, EVENT_REBASE_OK),
        (STAGE_REBASE, EVENT_REBASE_CONFLICT),
    )
    missing = [pair for pair in required_pairs if pair not in transition_table]
    if missing:
        formatted = ", ".join([f"{stage}+{event}" for stage, event in missing])
        raise TransitionError(f"Missing required transition(s): {formatted}")

