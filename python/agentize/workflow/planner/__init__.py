"""Planner pipeline package.

Runnable package for the multi-stage planner pipeline.
Supports `python -m agentize.workflow.planner` invocation.

Exports:
- run_planner_pipeline: Execute the 5-stage pipeline
- StageResult: Dataclass for per-stage results
"""

from agentize.workflow.planner.pipeline import (
    run_planner_pipeline,
    StageResult,
)

__all__ = ["run_planner_pipeline", "StageResult"]
