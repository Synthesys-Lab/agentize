"""Planner pipeline package.

Runnable package for the multi-stage planner pipeline.
Supports `python -m agentize.workflow.planner` invocation.

Exports:
- run_planner_pipeline: Execute the 5-stage pipeline
- StageResult: Dataclass for per-stage results
- PlannerTTY: Re-exported from utils for convenience
"""

from __future__ import annotations

import importlib

from agentize.workflow.utils import PlannerTTY

__all__ = ["run_planner_pipeline", "StageResult", "PlannerTTY"]


def __getattr__(name: str):
    if name in ("run_planner_pipeline", "StageResult"):
        module = importlib.import_module("agentize.workflow.planner.__main__")
        return getattr(module, name)
    if name == "PlannerTTY":
        return PlannerTTY
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def __dir__() -> list[str]:
    return sorted(__all__)
