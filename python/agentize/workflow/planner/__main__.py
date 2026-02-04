"""Python planner pipeline implementation.

5-stage workflow: understander → bold → critique → reducer → consensus.

Provides Python-native interfaces and the CLI backend used by `lol plan`.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from agentize.shell import resolve_repo_root
from agentize.workflow.api import run_acw
from agentize.workflow.api import gh as gh_utils
from agentize.workflow.planner.pipeline import run_consensus_stage, run_planner_pipeline


# ============================================================
# CLI Backend Helpers
# ============================================================


_PLAN_HEADER_RE = re.compile(r"^#\s*(Implementation|Consensus) Plan:\s*(.+)$")
_PLAN_HEADER_HINT_RE = re.compile(r"(Implementation Plan:|Consensus Plan:)", re.IGNORECASE)
_PLAN_FOOTER_RE = re.compile(r"^Plan based on commit (?:[0-9a-f]+|unknown)$")


def _resolve_commit_hash(repo_root: Path) -> str:
    """Resolve the current git commit hash for provenance."""
    result = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        if message:
            print(f"Warning: Failed to resolve git commit: {message}", file=sys.stderr)
        else:
            print("Warning: Failed to resolve git commit", file=sys.stderr)
        return "unknown"

    commit_hash = result.stdout.strip().lower()
    if not commit_hash or not re.fullmatch(r"[0-9a-f]+", commit_hash):
        print("Warning: Unable to parse git commit hash, using 'unknown'", file=sys.stderr)
        return "unknown"
    return commit_hash


def _append_plan_footer(consensus_path: Path, commit_hash: str) -> None:
    """Append the commit provenance footer to a consensus plan file."""
    footer_line = f"Plan based on commit {commit_hash}"
    try:
        content = consensus_path.read_text()
    except FileNotFoundError:
        print(
            f"Warning: Consensus plan missing, cannot append footer: {consensus_path}",
            file=sys.stderr,
        )
        return

    trimmed = content.rstrip("\n")
    if trimmed.endswith(footer_line):
        return

    with consensus_path.open("a") as handle:
        if content and not content.endswith("\n"):
            handle.write("\n")
        handle.write(f"{footer_line}\n")


def _strip_plan_footer(text: str) -> str:
    """Strip the trailing commit provenance footer from a plan body."""
    if not text:
        return text

    lines = text.splitlines()
    had_trailing_newline = text.endswith("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        return ""
    if not _PLAN_FOOTER_RE.match(lines[-1].strip()):
        return text
    lines.pop()
    result = "\n".join(lines)
    if had_trailing_newline and result:
        result += "\n"
    return result


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
        repo_root = resolve_repo_root()
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    os.environ["AGENTIZE_HOME"] = str(repo_root)
    output_dir = repo_root / ".tmp"
    output_dir.mkdir(parents=True, exist_ok=True)

    def _log(message: str) -> None:
        print(message, file=sys.stderr)

    def _log_verbose(message: str) -> None:
        if verbose:
            _log(message)

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
        issue_body = gh_utils.issue_body(refine_issue_number, cwd=repo_root)
        issue_url = gh_utils.issue_url(refine_issue_number, cwd=repo_root)
        issue_body = _strip_plan_footer(issue_body)
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
        short_desc = _shorten_feature_desc(feature_desc, max_len=50)
        title = f"[plan] placeholder: {short_desc}"
        issue_number, issue_url = gh_utils.issue_create(
            title,
            feature_desc,
            cwd=repo_root,
        )
        if not issue_number:
            print(
                f"Warning: Could not parse issue number from URL: {issue_url}",
                file=sys.stderr,
            )
        if issue_number:
            prefix_name = f"issue-{issue_number}"
            _log(f"Created placeholder issue #{issue_number}")
        else:
            print(
                "Warning: Issue creation failed, falling back to timestamp artifacts",
                file=sys.stderr,
            )
            prefix_name = timestamp
    else:
        prefix_name = timestamp

    _log("Starting multi-agent debate pipeline...")
    _log(f"Feature: {feature_desc}")
    _log_verbose(f"Artifacts prefix: {prefix_name}")
    _log_verbose("")

    try:
        results = run_planner_pipeline(
            feature_desc,
            output_dir=output_dir,
            backends=stage_backends,
            runner=run_acw,
            prefix=prefix_name,
            output_suffix=".txt",
            skip_consensus=True,
        )
    except (FileNotFoundError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    consensus_backend = stage_backends["consensus"]
    _log(f"Stage 5/5: Running consensus ({consensus_backend[0]}:{consensus_backend[1]})")

    try:
        consensus_result = run_consensus_stage(
            feature_desc,
            bold_path=results["bold"].output_path,
            critique_path=results["critique"].output_path,
            reducer_path=results["reducer"].output_path,
            output_dir=output_dir,
            prefix=prefix_name,
            stage_backends=stage_backends,
            runner=run_acw,
        )
    except (FileNotFoundError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

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
    commit_hash = _resolve_commit_hash(repo_root)
    _append_plan_footer(consensus_path, commit_hash)

    _log_verbose("")
    _log("Pipeline complete!")
    _log_verbose(f"Consensus plan: {consensus_display}")
    _log_verbose("")

    if issue_mode and issue_number:
        _log(f"Publishing plan to issue #{issue_number}...")
        plan_title = _extract_plan_title(consensus_path)
        if not plan_title:
            plan_title = _shorten_feature_desc(feature_desc, max_len=50)
        plan_title = _apply_issue_tag(plan_title, issue_number)
        gh_utils.issue_edit(
            issue_number,
            title=f"[plan] {plan_title}",
            body_file=consensus_path,
            cwd=repo_root,
        )
        gh_utils.label_add(issue_number, ["agentize:plan"], cwd=repo_root)
        if issue_url:
            _log(f"See the full plan at: {issue_url}")

    _log(f"See the full plan locally at: {consensus_display}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
