"""Python planner pipeline implementation.

5-stage workflow: understander → bold → critique → reducer → consensus

Mirrors src/cli/planner/pipeline.sh while providing Python-native interfaces.
"""

from __future__ import annotations

import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Optional

from agentize.shell import get_agentize_home


@dataclass
class StageResult:
    """Result for a single pipeline stage."""

    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess


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
    "bold": ("claude", "sonnet"),
    "critique": ("claude", "sonnet"),
    "reducer": ("claude", "sonnet"),
    "consensus": ("claude", "sonnet"),
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
# ACW Wrapper
# ============================================================


def run_acw(
    provider: str,
    model: str,
    input_file: str | Path,
    output_file: str | Path,
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
) -> subprocess.CompletedProcess:
    """Run acw shell function for a single stage.

    Args:
        provider: Backend provider (e.g., "claude", "codex")
        model: Model identifier (e.g., "sonnet", "opus")
        input_file: Path to input prompt file
        output_file: Path for stage output
        tools: Tool configuration (Claude provider only)
        permission_mode: Permission mode override (Claude provider only)
        extra_flags: Additional CLI flags
        timeout: Execution timeout in seconds (default: 900)

    Returns:
        subprocess.CompletedProcess with stdout/stderr captured

    Raises:
        subprocess.TimeoutExpired: If execution exceeds timeout
    """
    agentize_home = get_agentize_home()
    acw_script = os.path.join(agentize_home, "src", "cli", "acw.sh")

    # Build command arguments
    cmd_parts = [provider, model, str(input_file), str(output_file)]

    # Add Claude-specific flags
    if provider == "claude":
        if tools:
            cmd_parts.extend(["--tools", tools])
        if permission_mode:
            cmd_parts.extend(["--permission-mode", permission_mode])

    # Add extra flags
    if extra_flags:
        cmd_parts.extend(extra_flags)

    # Quote paths to handle spaces
    cmd_args = " ".join(f'"{arg}"' for arg in cmd_parts)
    bash_cmd = f'source "{acw_script}" && acw {cmd_args}'

    # Set up environment
    env = os.environ.copy()
    env["AGENTIZE_HOME"] = agentize_home

    return subprocess.run(
        ["bash", "-c", bash_cmd],
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


# ============================================================
# Prompt Rendering
# ============================================================


def _strip_yaml_frontmatter(content: str) -> str:
    """Remove YAML frontmatter from markdown content."""
    # Match frontmatter between --- delimiters at start
    pattern = r"^---\s*\n.*?\n---\s*\n"
    return re.sub(pattern, "", content, count=1, flags=re.DOTALL)


def _read_prompt_file(path: Path) -> str:
    """Read a prompt file, stripping YAML frontmatter."""
    if not path.exists():
        raise FileNotFoundError(f"Prompt file not found: {path}")
    content = path.read_text()
    return _strip_yaml_frontmatter(content)


def _render_stage_prompt(
    stage: str,
    feature_desc: str,
    agentize_home: Path,
    previous_output: str | None = None,
) -> str:
    """Render the input prompt for a stage.

    Args:
        stage: Stage name
        feature_desc: Feature request description
        agentize_home: Path to agentize repository root
        previous_output: Output from previous stage (if any)

    Returns:
        Rendered prompt content
    """
    parts = []

    # Add agent base prompt (if not consensus)
    if stage in AGENT_PROMPTS:
        agent_path = agentize_home / AGENT_PROMPTS[stage]
        parts.append(_read_prompt_file(agent_path))

    # Add plan-guideline for applicable stages
    if stage in STAGES_WITH_PLAN_GUIDELINE:
        plan_guideline_path = (
            agentize_home / ".claude-plugin/skills/plan-guideline/SKILL.md"
        )
        if plan_guideline_path.exists():
            parts.append("\n---\n")
            parts.append("# Planning Guidelines\n")
            parts.append(_read_prompt_file(plan_guideline_path))

    # Add feature description
    parts.append("\n---\n")
    parts.append("# Feature Request\n")
    parts.append(feature_desc)

    # Add previous stage output if provided
    if previous_output:
        parts.append("\n---\n")
        parts.append("# Previous Stage Output\n")
        parts.append(previous_output)

    return "\n".join(parts)


def _render_consensus_prompt(
    feature_desc: str,
    bold_output: str,
    critique_output: str,
    reducer_output: str,
    agentize_home: Path,
) -> str:
    """Render the consensus prompt with combined report.

    Args:
        feature_desc: Original feature request
        bold_output: Bold proposer output
        critique_output: Critique output
        reducer_output: Reducer output
        agentize_home: Path to agentize repository root

    Returns:
        Rendered consensus prompt
    """
    template_path = (
        agentize_home
        / ".claude-plugin/skills/external-consensus/external-review-prompt.md"
    )
    template = _read_prompt_file(template_path)

    # Build combined report
    combined_report = f"""## Bold Proposer Output

{bold_output}

## Critique Output

{critique_output}

## Reducer Output

{reducer_output}
"""

    # Replace placeholders
    prompt = template.replace("{{FEATURE_DESCRIPTION}}", feature_desc)
    prompt = prompt.replace("{{COMBINED_REPORT}}", combined_report)

    return prompt


# ============================================================
# Pipeline Orchestration
# ============================================================


def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    parallel: bool = True,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
) -> dict[str, StageResult]:
    """Execute the 5-stage planner pipeline.

    Args:
        feature_desc: Feature request description to plan
        output_dir: Directory for artifacts (default: .tmp)
        backends: Provider/model mapping per stage (default: all use claude/sonnet)
        parallel: Run critique and reducer in parallel (default: True)
        runner: Callable for stage execution (injectable for testing)
        prefix: Artifact filename prefix (default: timestamp-based)

    Returns:
        Dict mapping stage names to StageResult objects

    Raises:
        FileNotFoundError: If required prompt templates are missing
        RuntimeError: If a stage execution fails
    """
    agentize_home = Path(get_agentize_home())
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Determine artifact prefix
    if prefix is None:
        prefix = datetime.now().strftime("%Y%m%d-%H%M%S")

    # Merge backends with defaults
    stage_backends = {**DEFAULT_BACKENDS}
    if backends:
        stage_backends.update(backends)

    results: dict[str, StageResult] = {}

    def _run_stage(
        stage: str,
        input_content: str,
        previous_output: str | None = None,
    ) -> StageResult:
        """Run a single stage and return result."""
        input_path = output_path / f"{prefix}-{stage}-input.md"
        output_file = output_path / f"{prefix}-{stage}-output.md"

        # Write input prompt
        input_path.write_text(input_content)

        # Get backend configuration
        provider, model = stage_backends[stage]

        # Run stage
        process = runner(
            provider,
            model,
            input_path,
            output_file,
            tools=STAGE_TOOLS.get(stage),
            permission_mode=STAGE_PERMISSION_MODE.get(stage),
        )

        return StageResult(
            stage=stage,
            input_path=input_path,
            output_path=output_file,
            process=process,
        )

    def _check_stage_result(result: StageResult) -> None:
        """Check if stage succeeded, raise RuntimeError if not."""
        if result.process.returncode != 0:
            raise RuntimeError(
                f"Stage '{result.stage}' failed with exit code {result.process.returncode}"
            )
        if not result.output_path.exists() or result.output_path.stat().st_size == 0:
            raise RuntimeError(f"Stage '{result.stage}' produced no output")

    # ── Stage 1: Understander ──
    understander_prompt = _render_stage_prompt(
        "understander", feature_desc, agentize_home
    )
    results["understander"] = _run_stage("understander", understander_prompt)
    _check_stage_result(results["understander"])
    understander_output = results["understander"].output_path.read_text()

    # ── Stage 2: Bold ──
    bold_prompt = _render_stage_prompt(
        "bold", feature_desc, agentize_home, understander_output
    )
    results["bold"] = _run_stage("bold", bold_prompt)
    _check_stage_result(results["bold"])
    bold_output = results["bold"].output_path.read_text()

    # ── Stage 3 & 4: Critique and Reducer ──
    critique_prompt = _render_stage_prompt(
        "critique", feature_desc, agentize_home, bold_output
    )
    reducer_prompt = _render_stage_prompt(
        "reducer", feature_desc, agentize_home, bold_output
    )

    if parallel:
        # Run in parallel using ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=2) as executor:
            critique_future = executor.submit(_run_stage, "critique", critique_prompt)
            reducer_future = executor.submit(_run_stage, "reducer", reducer_prompt)

            results["critique"] = critique_future.result()
            results["reducer"] = reducer_future.result()
    else:
        # Run sequentially
        results["critique"] = _run_stage("critique", critique_prompt)
        results["reducer"] = _run_stage("reducer", reducer_prompt)

    _check_stage_result(results["critique"])
    _check_stage_result(results["reducer"])
    critique_output = results["critique"].output_path.read_text()
    reducer_output = results["reducer"].output_path.read_text()

    # ── Stage 5: Consensus ──
    consensus_prompt = _render_consensus_prompt(
        feature_desc, bold_output, critique_output, reducer_output, agentize_home
    )
    results["consensus"] = _run_stage("consensus", consensus_prompt)
    _check_stage_result(results["consensus"])

    return results
