"""Python planner pipeline implementation.

5-stage workflow: understander → bold → critique → reducer → consensus.

Provides Python-native interfaces and the CLI backend used by `lol plan`.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Optional

from agentize.shell import get_agentize_home
from agentize.workflow.utils import PlannerTTY, run_acw


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
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
    progress: Optional[PlannerTTY] = None,
) -> dict[str, StageResult]:
    """Execute the 5-stage planner pipeline.

    Args:
        feature_desc: Feature request description to plan
        output_dir: Directory for artifacts (default: .tmp)
        backends: Provider/model mapping per stage (default: understander uses claude/sonnet, others claude/opus)
        parallel: Run critique and reducer in parallel (default: True)
        runner: Callable for stage execution (injectable for testing)
        prefix: Artifact filename prefix (default: timestamp-based)
        output_suffix: Suffix appended to stage output filenames
        skip_consensus: Skip the consensus stage (default: False)
        progress: Optional TTY progress helper for stage logging/animation

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

    def _backend_label(stage: str) -> str:
        provider, model = stage_backends[stage]
        return f"{provider}:{model}"

    def _run_stage(
        stage: str,
        input_content: str,
        previous_output: str | None = None,
    ) -> StageResult:
        """Run a single stage and return result."""
        input_path = output_path / f"{prefix}-{stage}-input.md"
        output_file = output_path / f"{prefix}-{stage}{output_suffix}"

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
    t_understander = progress.timer_start() if progress else None
    if progress:
        progress.anim_start(
            f"Stage 1/5: Running understander ({_backend_label('understander')})"
        )
    try:
        results["understander"] = _run_stage("understander", understander_prompt)
    finally:
        if progress:
            progress.anim_stop()
    _check_stage_result(results["understander"])
    understander_output = results["understander"].output_path.read_text()
    if progress and t_understander is not None:
        progress.timer_log("understander", t_understander, _backend_label("understander"))
        progress.log(f"  Understander complete: {results['understander'].output_path}")
        progress.log("")

    # ── Stage 2: Bold ──
    bold_prompt = _render_stage_prompt(
        "bold", feature_desc, agentize_home, understander_output
    )
    t_bold = progress.timer_start() if progress else None
    if progress:
        progress.anim_start(f"Stage 2/5: Running bold-proposer ({_backend_label('bold')})")
    try:
        results["bold"] = _run_stage("bold", bold_prompt)
    finally:
        if progress:
            progress.anim_stop()
    _check_stage_result(results["bold"])
    bold_output = results["bold"].output_path.read_text()
    if progress and t_bold is not None:
        progress.timer_log("bold-proposer", t_bold, _backend_label("bold"))
        progress.log(f"  Bold-proposer complete: {results['bold'].output_path}")
        progress.log("")

    # ── Stage 3 & 4: Critique and Reducer ──
    critique_prompt = _render_stage_prompt(
        "critique", feature_desc, agentize_home, bold_output
    )
    reducer_prompt = _render_stage_prompt(
        "reducer", feature_desc, agentize_home, bold_output
    )

    t_parallel = progress.timer_start() if progress else None
    if progress:
        progress.anim_start(
            "Stage 3-4/5: Running critique and reducer in parallel "
            f"({_backend_label('critique')}, {_backend_label('reducer')})"
        )
    try:
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
    finally:
        if progress:
            progress.anim_stop()
    _check_stage_result(results["critique"])
    _check_stage_result(results["reducer"])
    critique_output = results["critique"].output_path.read_text()
    reducer_output = results["reducer"].output_path.read_text()
    if progress and t_parallel is not None:
        progress.timer_log("critique", t_parallel, _backend_label("critique"))
        progress.log(f"  Critique complete: {results['critique'].output_path}")
        progress.timer_log("reducer", t_parallel, _backend_label("reducer"))
        progress.log(f"  Reducer complete: {results['reducer'].output_path}")
        progress.log("")

    if skip_consensus:
        return results

    # ── Stage 5: Consensus ──
    consensus_prompt = _render_consensus_prompt(
        feature_desc, bold_output, critique_output, reducer_output, agentize_home
    )
    t_consensus = progress.timer_start() if progress else None
    if progress:
        progress.anim_start(
            f"Stage 5/5: Running consensus ({_backend_label('consensus')})"
        )
    try:
        results["consensus"] = _run_stage("consensus", consensus_prompt)
    finally:
        if progress:
            progress.anim_stop()
    _check_stage_result(results["consensus"])
    if progress and t_consensus is not None:
        progress.timer_log("consensus", t_consensus, _backend_label("consensus"))

    return results


# ============================================================
# CLI Backend Helpers
# ============================================================


_PLAN_HEADER_RE = re.compile(r"^#\s*(Implementation|Consensus) Plan:\s*(.+)$")
_PLAN_HEADER_HINT_RE = re.compile(r"(Implementation Plan:|Consensus Plan:)", re.IGNORECASE)


def _resolve_repo_root() -> Path:
    """Resolve repo root using AGENTIZE_HOME or git rev-parse."""
    env_home = os.environ.get("AGENTIZE_HOME")
    if env_home:
        repo_root = Path(env_home).expanduser()
        if repo_root.is_dir():
            return repo_root

    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        root = result.stdout.strip()
        if root:
            return Path(root)

    raise RuntimeError(
        "Could not determine repo root. Set AGENTIZE_HOME or run inside a git repo."
    )


def _load_planner_backend_config(repo_root: Path, start_dir: Path) -> dict[str, str]:
    """Load planner backend overrides from .agentize.local.yaml."""
    plugin_dir = repo_root / ".claude-plugin"
    if str(plugin_dir) not in sys.path:
        sys.path.insert(0, str(plugin_dir))

    try:
        from lib.local_config_io import find_local_config_file, parse_yaml_file
    except Exception as exc:
        raise RuntimeError(f"Planner config helper not found: {exc}") from exc

    config_path = find_local_config_file(start_dir)
    if config_path is None:
        return {}

    config = parse_yaml_file(config_path)
    planner = config.get("planner")
    if planner is None:
        return {}
    if not isinstance(planner, dict):
        raise ValueError(f"planner section in {config_path} must be a mapping")

    backend_config: dict[str, str] = {}
    for key in ("backend", "understander", "bold", "critique", "reducer"):
        if key not in planner:
            continue
        value = planner.get(key)
        if value is None:
            continue
        if not isinstance(value, str):
            raise ValueError(f"planner.{key} in {config_path} must be a string")
        value = value.strip()
        if not value:
            continue
        backend_config[key] = value

    return backend_config


def _validate_backend_spec(spec: str, label: str) -> None:
    """Validate backend spec format (provider:model)."""
    if not spec:
        return
    if ":" not in spec:
        raise ValueError(f"Invalid {label} backend '{spec}' (expected provider:model)")
    provider, model = spec.split(":", 1)
    if not provider or not model:
        raise ValueError(f"Invalid {label} backend '{spec}' (expected provider:model)")


def _split_backend_spec(spec: str) -> tuple[str, str]:
    provider, model = spec.split(":", 1)
    return provider.strip(), model.strip()


def _resolve_stage_backends(backend_config: dict[str, str]) -> dict[str, tuple[str, str]]:
    defaults = {
        "understander": "claude:sonnet",
        "bold": "claude:opus",
        "critique": "claude:opus",
        "reducer": "claude:opus",
        "consensus": "claude:opus",
    }
    backend_override = backend_config.get("backend")
    if backend_override:
        for key in defaults:
            defaults[key] = backend_override

    stage_specs = {
        "understander": backend_config.get("understander", defaults["understander"]),
        "bold": backend_config.get("bold", defaults["bold"]),
        "critique": backend_config.get("critique", defaults["critique"]),
        "reducer": backend_config.get("reducer", defaults["reducer"]),
        "consensus": defaults["consensus"],
    }

    for key, value in stage_specs.items():
        _validate_backend_spec(value, f"planner.{key}")

    return {key: _split_backend_spec(spec) for key, spec in stage_specs.items()}


def _collapse_whitespace(text: str) -> str:
    return " ".join(text.split())


def _shorten_feature_desc(desc: str, max_len: int = 50) -> str:
    normalized = _collapse_whitespace(desc)
    if len(normalized) <= max_len:
        return normalized
    return f"{normalized[:max_len]}..."


def _gh_available() -> bool:
    if shutil.which("gh") is None:
        return False
    result = subprocess.run(
        ["gh", "auth", "status"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _issue_create(feature_desc: str) -> tuple[Optional[str], Optional[str]]:
    if not _gh_available():
        print(
            "Warning: gh CLI not available or not authenticated, skipping issue creation",
            file=sys.stderr,
        )
        return None, None

    short_desc = _shorten_feature_desc(feature_desc, max_len=50)
    title = f"[plan] placeholder: {short_desc}"
    process = subprocess.run(
        ["gh", "issue", "create", "--title", title, "--body", feature_desc],
        capture_output=True,
        text=True,
    )
    if process.returncode != 0 or not process.stdout.strip():
        msg = process.stdout.strip() or process.stderr.strip()
        print(f"Warning: Failed to create GitHub issue: {msg}", file=sys.stderr)
        return None, None

    issue_url = process.stdout.strip().splitlines()[-1]
    match = re.search(r"([0-9]+)$", issue_url)
    if not match:
        print(f"Warning: Could not parse issue number from URL: {issue_url}", file=sys.stderr)
        return None, issue_url

    return match.group(1), issue_url


def _issue_fetch(issue_number: str) -> tuple[str, Optional[str]]:
    if not _gh_available():
        raise RuntimeError(
            f"gh CLI not available or not authenticated; cannot refine issue #{issue_number}"
        )

    body_proc = subprocess.run(
        ["gh", "issue", "view", issue_number, "--json", "body", "-q", ".body"],
        capture_output=True,
        text=True,
    )
    if body_proc.returncode != 0:
        raise RuntimeError(f"Failed to fetch issue #{issue_number} body")

    url_proc = subprocess.run(
        ["gh", "issue", "view", issue_number, "--json", "url", "-q", ".url"],
        capture_output=True,
        text=True,
    )
    issue_url = url_proc.stdout.strip() if url_proc.returncode == 0 else None

    return body_proc.stdout, issue_url


def _issue_publish(issue_number: str, title: str, body_file: Path) -> bool:
    if not _gh_available():
        print("Warning: gh CLI not available, skipping issue publish", file=sys.stderr)
        return False

    edit_proc = subprocess.run(
        ["gh", "issue", "edit", issue_number, "--title", f"[plan] {title}", "--body-file", str(body_file)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if edit_proc.returncode != 0:
        print(f"Warning: Failed to update issue #{issue_number} body", file=sys.stderr)
        return False

    label_proc = subprocess.run(
        ["gh", "issue", "edit", issue_number, "--add-label", "agentize:plan"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if label_proc.returncode != 0:
        print(
            f"Warning: Failed to add agentize:plan label to issue #{issue_number}",
            file=sys.stderr,
        )

    return True


def _extract_plan_title(consensus_path: Path) -> str:
    try:
        for line in consensus_path.read_text().splitlines():
            match = _PLAN_HEADER_RE.match(line.strip())
            if match:
                return match.group(2).strip()
    except FileNotFoundError:
        return ""
    return ""


def _apply_issue_tag(plan_title: str, issue_number: str) -> str:
    issue_tag = f"[#{issue_number}]"
    if plan_title.startswith(issue_tag):
        return plan_title
    if plan_title.startswith(f"{issue_tag} "):
        return plan_title
    if plan_title:
        return f"{issue_tag} {plan_title}"
    return issue_tag


def _run_consensus_stage(
    feature_desc: str,
    bold_path: Path,
    critique_path: Path,
    reducer_path: Path,
    output_dir: Path,
    prefix: str,
    stage_backends: dict[str, tuple[str, str]],
    *,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
) -> StageResult:
    bold_output = bold_path.read_text()
    critique_output = critique_path.read_text()
    reducer_output = reducer_path.read_text()
    agentize_home = Path(get_agentize_home())

    consensus_prompt = _render_consensus_prompt(
        feature_desc,
        bold_output,
        critique_output,
        reducer_output,
        agentize_home,
    )

    input_path = output_dir / f"{prefix}-consensus-input.md"
    output_path = output_dir / f"{prefix}-consensus.md"
    input_path.write_text(consensus_prompt)

    provider, model = stage_backends["consensus"]
    process = runner(
        provider,
        model,
        input_path,
        output_path,
        tools=STAGE_TOOLS.get("consensus"),
        permission_mode=STAGE_PERMISSION_MODE.get("consensus"),
    )

    return StageResult(
        stage="consensus",
        input_path=input_path,
        output_path=output_path,
        process=process,
    )


def main(argv: list[str]) -> int:
    """CLI entrypoint for planner pipeline orchestration."""
    parser = argparse.ArgumentParser(description="Planner pipeline backend")
    parser.add_argument("--feature-desc", default="", help="Feature description or refine focus")
    parser.add_argument("--issue-mode", default="true", choices=["true", "false"])
    parser.add_argument("--verbose", default="false", choices=["true", "false"])
    parser.add_argument("--refine-issue-number", default="")
    args = parser.parse_args(argv)

    issue_mode = args.issue_mode == "true"
    verbose = args.verbose == "true"
    refine_issue_number = args.refine_issue_number.strip()
    feature_desc = args.feature_desc

    try:
        repo_root = _resolve_repo_root()
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    os.environ["AGENTIZE_HOME"] = str(repo_root)
    output_dir = repo_root / ".tmp"
    output_dir.mkdir(parents=True, exist_ok=True)

    tty = PlannerTTY(verbose=verbose)

    try:
        backend_config = _load_planner_backend_config(repo_root, Path.cwd())
        stage_backends = _resolve_stage_backends(backend_config)
    except (RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    issue_number: Optional[str] = None
    issue_url: Optional[str] = None

    if refine_issue_number:
        refine_instructions = feature_desc
        try:
            issue_body, issue_url = _issue_fetch(refine_issue_number)
        except RuntimeError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1
        if not _PLAN_HEADER_HINT_RE.search(issue_body):
            print(
                f"Warning: Issue #{refine_issue_number} does not look like a plan "
                "(missing Implementation/Consensus Plan headers)",
                file=sys.stderr,
            )
        feature_desc = issue_body
        if refine_instructions:
            feature_desc = f"{feature_desc}\n\nRefinement focus:\n{refine_instructions}"
        issue_number = refine_issue_number
        prefix_name = f"issue-refine-{refine_issue_number}"
    elif issue_mode:
        issue_number, issue_url = _issue_create(feature_desc)
        if issue_number:
            prefix_name = f"issue-{issue_number}"
            tty.stage(f"Created placeholder issue #{issue_number}")
        else:
            print(
                "Warning: Issue creation failed, falling back to timestamp artifacts",
                file=sys.stderr,
            )
            prefix_name = timestamp
    else:
        prefix_name = timestamp

    tty.stage("Starting multi-agent debate pipeline...")
    tty.print_feature(feature_desc)
    tty.log(f"Artifacts prefix: {prefix_name}")
    tty.log("")

    try:
        results = run_planner_pipeline(
            feature_desc,
            output_dir=output_dir,
            backends=stage_backends,
            runner=run_acw,
            prefix=prefix_name,
            output_suffix=".txt",
            skip_consensus=True,
            progress=tty,
        )
    except (FileNotFoundError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    consensus_backend = stage_backends["consensus"]
    t_consensus = tty.timer_start()
    tty.anim_start(f"Stage 5/5: Running consensus ({consensus_backend[0]}:{consensus_backend[1]})")
    try:
        consensus_result = _run_consensus_stage(
            feature_desc,
            results["bold"].output_path,
            results["critique"].output_path,
            results["reducer"].output_path,
            output_dir,
            prefix_name,
            stage_backends,
            runner=run_acw,
        )
    except (FileNotFoundError, RuntimeError, subprocess.TimeoutExpired) as exc:
        tty.anim_stop()
        print(f"Error: {exc}", file=sys.stderr)
        return 2
    tty.anim_stop()

    if consensus_result.process.returncode != 0:
        print(
            f"Error: Consensus stage failed with exit code {consensus_result.process.returncode}",
            file=sys.stderr,
        )
        return 2
    if (
        not consensus_result.output_path.exists()
        or consensus_result.output_path.stat().st_size == 0
    ):
        print("Error: Consensus plan output is missing or empty", file=sys.stderr)
        return 2

    try:
        consensus_display = str(consensus_result.output_path.relative_to(repo_root))
    except ValueError:
        consensus_display = str(consensus_result.output_path)
    consensus_path = consensus_result.output_path

    tty.timer_log("consensus", t_consensus, f"{consensus_backend[0]}:{consensus_backend[1]}")

    tty.log("")
    tty.stage("Pipeline complete!")
    tty.log(f"Consensus plan: {consensus_display}")
    tty.log("")

    if issue_mode and issue_number:
        tty.stage(f"Publishing plan to issue #{issue_number}...")
        plan_title = _extract_plan_title(consensus_path)
        if not plan_title:
            plan_title = _shorten_feature_desc(feature_desc, max_len=50)
        plan_title = _apply_issue_tag(plan_title, issue_number)
        if not _issue_publish(issue_number, plan_title, consensus_path):
            print(
                f"Warning: Failed to publish plan to issue #{issue_number}",
                file=sys.stderr,
            )
        if issue_url:
            tty.term_label("See the full plan at:", issue_url, "success")

    tty.term_label("See the full plan locally at:", consensus_display, "info")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
