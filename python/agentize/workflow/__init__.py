"""Python planner workflow orchestration.

Public interfaces for running the 5-stage planner pipeline:
- run_acw: Wrapper around acw shell function
- run_planner_pipeline: Execute full pipeline with stage results
- StageResult: Dataclass for per-stage results
- PlannerTTY: Terminal output helper with animation support
"""

from __future__ import annotations

import importlib

from agentize.workflow.utils import run_acw, PlannerTTY

__all__ = ["run_acw", "run_planner_pipeline", "StageResult", "PlannerTTY"]


def __getattr__(name: str):
    if name in ("run_planner_pipeline", "StageResult"):
        planner = importlib.import_module("agentize.workflow.planner")
        return getattr(planner, name)
    if name in ("run_acw", "PlannerTTY"):
        return globals()[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def __dir__() -> list[str]:
    return sorted(__all__)
