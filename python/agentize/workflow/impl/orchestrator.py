"""Finite-state orchestrator for the impl workflow."""

from __future__ import annotations

from collections.abc import Callable

from agentize.workflow.impl.state import (
    EVENT_FATAL,
    STAGE_FATAL,
    STAGE_FINISH,
    Stage,
    StageResult,
    WorkflowContext,
)
from agentize.workflow.impl.transition import TransitionError, next_stage


StageHandler = Callable[[WorkflowContext], StageResult]
KernelRegistry = dict[Stage, StageHandler]


class OrchestratorError(RuntimeError):
    """Raised when orchestrator encounters invalid runtime wiring."""


def _format_stage_log(stage: Stage, result: StageResult, iteration: int) -> str:
    reason = result.reason or "n/a"
    return f"stage={stage} event={result.event} iter={iteration} reason={reason}"


def run_fsm_orchestrator(
    context: WorkflowContext,
    *,
    kernels: KernelRegistry,
    logger: Callable[[str], None] = print,
    max_steps: int = 200,
) -> WorkflowContext:
    """Run a flat FSM loop until `finish` or `fatal` stage is reached."""
    step = 0

    while context.current_stage not in (STAGE_FINISH, STAGE_FATAL):
        step += 1
        if step > max_steps:
            context.current_stage = STAGE_FATAL
            context.final_status = "fatal"
            context.fatal_reason = f"Max FSM steps exceeded: {max_steps}"
            break

        handler = kernels.get(context.current_stage)
        if handler is None:
            context.current_stage = STAGE_FATAL
            context.final_status = "fatal"
            context.fatal_reason = f"No kernel for stage: {context.current_stage}"
            break

        context.bump_attempt(context.current_stage)
        result = handler(context)
        context.apply_stage_result(result)

        logger(_format_stage_log(context.current_stage, result, step))

        try:
            context.current_stage = next_stage(context.current_stage, result.event)
        except TransitionError as exc:
            context.current_stage = STAGE_FATAL
            context.final_status = "fatal"
            context.fatal_reason = str(exc)
            logger(_format_stage_log(STAGE_FATAL, StageResult(event=EVENT_FATAL, reason=str(exc)), step))
            break

    if context.current_stage == STAGE_FINISH:
        context.final_status = "finish"
    elif context.current_stage == STAGE_FATAL:
        context.final_status = "fatal"
        if not context.fatal_reason:
            context.fatal_reason = "Fatal stage reached"

    return context

