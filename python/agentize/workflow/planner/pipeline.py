"""Planner pipeline orchestration using the Session DSL."""

from __future__ import annotations

import subprocess
from datetime import datetime
from pathlib import Path
from typing import Callable

from agentize.shell import get_agentize_home
from agentize.workflow.api import run_acw
from agentize.workflow.api import prompt as prompt_utils
from agentize.workflow.api.session import Session, StageResult


# ============================================================
# Stage Configuration
# ============================================================

# Stage names in execution order
STAGES = ["understander", "bold", "critique", "reducer", "consensus"]

# Agent prompt paths (relative to AGENTIZE_HOME)
AGENT_PROMPTS = {
    "understander": ".claude-plugin/agents/understander.md",
    "bold": ".claude-plugin/agents/bold-proposer.md",
    "critique": ".claude-plugin/agents/proposal-critique.md",
    "reducer": ".claude-plugin/agents/proposal-reducer.md",
}

# Stages that include plan-guideline content
STAGES_WITH_PLAN_GUIDELINE = {"bold", "critique", "reducer"}

# Default backends per stage (provider, model)
DEFAULT_BACKENDS = {
    "understander": ("claude", "sonnet"),
    "bold": ("claude", "opus"),
    "critique": ("claude", "opus"),
    "reducer": ("claude", "opus"),
    "consensus": ("claude", "opus"),
}

# Tool configurations per stage (Claude provider only)
STAGE_TOOLS = {
    "understander": "Read,Grep,Glob",
    "bold": "Read,Grep,Glob,WebSearch,WebFetch",
    "critique": "Read,Grep,Glob,Bash",
    "reducer": "Read,Grep,Glob",
    "consensus": "Read,Grep,Glob",
}

# Permission mode per stage (Claude provider only)
STAGE_PERMISSION_MODE = {
    "bold": "plan",
}


# ============================================================
# Prompt Rendering
# ============================================================


def _render_stage_prompt(
    stage: str,
    feature_desc: str,
    agentize_home: Path,
    previous_output: str | None = None,
) -> str:
    """Render the input prompt for a stage."""
    parts = []

    if stage in AGENT_PROMPTS:
        agent_path = agentize_home / AGENT_PROMPTS[stage]
        parts.append(prompt_utils.read_prompt(agent_path, strip_frontmatter=True))

    if stage in STAGES_WITH_PLAN_GUIDELINE:
        plan_guideline_path = (
            agentize_home / ".claude-plugin/skills/plan-guideline/SKILL.md"
        )
        if plan_guideline_path.exists():
            parts.append("\n---\n")
            parts.append("# Planning Guidelines\n")
            parts.append(prompt_utils.read_prompt(plan_guideline_path, strip_frontmatter=True))

    parts.append("\n---\n")
    parts.append("# Feature Request\n")
    parts.append(feature_desc)

    if previous_output:
        parts.append("\n---\n")
        parts.append("# Previous Stage Output\n")
        parts.append(previous_output)

    return "\n".join(parts)


def _build_combined_report(
    bold_output: str,
    critique_output: str,
    reducer_output: str,
) -> str:
    """Build the combined report for the consensus template."""
    return f"""## Bold Proposer Output

{bold_output}

## Critique Output

{critique_output}

## Reducer Output

{reducer_output}
"""


def _render_consensus_prompt(
    feature_desc: str,
    combined_report: str,
    agentize_home: Path,
    dest_path: Path,
) -> str:
    """Render the consensus prompt with combined report and write to dest_path."""
    template_path = (
        agentize_home
        / ".claude-plugin/skills/external-consensus/external-review-prompt.md"
    )
    return prompt_utils.render(
        template_path,
        {"FEATURE_DESCRIPTION": feature_desc, "COMBINED_REPORT": combined_report},
        dest_path,
        strip_frontmatter=True,
    )


# ============================================================
# Pipeline Orchestration
# ============================================================


def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
) -> dict[str, StageResult]:
    """Execute the 5-stage planner pipeline."""
    agentize_home = Path(get_agentize_home())
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    if prefix is None:
        prefix = datetime.now().strftime("%Y%m%d-%H%M%S")

    stage_backends = {**DEFAULT_BACKENDS}
    if backends:
        stage_backends.update(backends)

    session = Session(
        output_dir=output_path,
        prefix=prefix,
        runner=runner,
        output_suffix=output_suffix,
    )

    def _log_stage(message: str) -> None:
        session._log(message)

    def _backend_label(stage: str) -> str:
        provider, model = stage_backends[stage]
        return f"{provider}:{model}"

    results: dict[str, StageResult] = {}

    understander_prompt = _render_stage_prompt(
        "understander", feature_desc, agentize_home
    )
    _log_stage(f"Stage 1/5: Running understander ({_backend_label('understander')})")
    results["understander"] = session.run_prompt(
        "understander",
        understander_prompt,
        stage_backends["understander"],
        tools=STAGE_TOOLS.get("understander"),
        permission_mode=STAGE_PERMISSION_MODE.get("understander"),
    )
    understander_output = results["understander"].text()

    bold_prompt = _render_stage_prompt(
        "bold", feature_desc, agentize_home, understander_output
    )
    _log_stage(f"Stage 2/5: Running bold-proposer ({_backend_label('bold')})")
    results["bold"] = session.run_prompt(
        "bold",
        bold_prompt,
        stage_backends["bold"],
        tools=STAGE_TOOLS.get("bold"),
        permission_mode=STAGE_PERMISSION_MODE.get("bold"),
    )
    bold_output = results["bold"].text()

    critique_prompt = _render_stage_prompt(
        "critique", feature_desc, agentize_home, bold_output
    )
    reducer_prompt = _render_stage_prompt(
        "reducer", feature_desc, agentize_home, bold_output
    )

    _log_stage(
        "Stage 3-4/5: Running critique and reducer in parallel "
        f"({_backend_label('critique')}, {_backend_label('reducer')})"
    )

    parallel_results = session.run_parallel(
        [
            session.stage(
                "critique",
                critique_prompt,
                stage_backends["critique"],
                tools=STAGE_TOOLS.get("critique"),
                permission_mode=STAGE_PERMISSION_MODE.get("critique"),
            ),
            session.stage(
                "reducer",
                reducer_prompt,
                stage_backends["reducer"],
                tools=STAGE_TOOLS.get("reducer"),
                permission_mode=STAGE_PERMISSION_MODE.get("reducer"),
            ),
        ]
    )
    results.update(parallel_results)

    critique_output = results["critique"].text()
    reducer_output = results["reducer"].text()

    if skip_consensus:
        return results

    combined_report = _build_combined_report(
        bold_output, critique_output, reducer_output
    )

    def _write_consensus_prompt(path: Path) -> str:
        return _render_consensus_prompt(
            feature_desc,
            combined_report,
            agentize_home,
            path,
        )

    _log_stage(f"Stage 5/5: Running consensus ({_backend_label('consensus')})")
    results["consensus"] = session.run_prompt(
        "consensus",
        _write_consensus_prompt,
        stage_backends["consensus"],
        tools=STAGE_TOOLS.get("consensus"),
        permission_mode=STAGE_PERMISSION_MODE.get("consensus"),
    )

    return results


def run_consensus_stage(
    feature_desc: str,
    *,
    bold_path: Path,
    critique_path: Path,
    reducer_path: Path,
    output_dir: Path,
    prefix: str,
    stage_backends: dict[str, tuple[str, str]],
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
) -> StageResult:
    """Run the consensus stage independently."""
    bold_output = bold_path.read_text()
    critique_output = critique_path.read_text()
    reducer_output = reducer_path.read_text()
    agentize_home = Path(get_agentize_home())

    combined_report = _build_combined_report(
        bold_output,
        critique_output,
        reducer_output,
    )

    input_path = output_dir / f"{prefix}-consensus-input.md"
    output_path = output_dir / f"{prefix}-consensus.md"

    def _write_consensus_prompt(path: Path) -> str:
        return _render_consensus_prompt(
            feature_desc,
            combined_report,
            agentize_home,
            path,
        )

    session = Session(output_dir=output_dir, prefix=prefix, runner=runner)
    return session.run_prompt(
        "consensus",
        _write_consensus_prompt,
        stage_backends["consensus"],
        tools=STAGE_TOOLS.get("consensus"),
        permission_mode=STAGE_PERMISSION_MODE.get("consensus"),
        input_path=input_path,
        output_path=output_path,
    )


__all__ = ["run_planner_pipeline", "run_consensus_stage", "StageResult"]
