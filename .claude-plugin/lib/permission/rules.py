"""Permission rules for tool usage.

This module defines PERMISSION_RULES and provides rule matching logic.
Priority: deny -> ask -> allow (first match wins)

Rule sources:
1. Hardcoded rules in PERMISSION_RULES (this file)
2. Project rules from .agentize.yaml
3. Local rules from .agentize.local.yaml

Hardcoded deny rules always take precedence over YAML allows.
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Any, Optional

import yaml

# Module-level cache for YAML rules
_yaml_rules_cache: Optional[dict] = None
_yaml_mtimes: dict[str, float] = {}

# Permission rules: (tool_name, regex_pattern)
PERMISSION_RULES = {
    'allow': [
        # Skills
        ('Skill', r'^open-pr'),
        ('Skill', r'^open-issue'),
        ('Skill', r'^fork-dev-branch'),
        ('Skill', r'^commit-msg'),
        ('Skill', r'^review-standard'),
        ('Skill', r'^external-consensus'),
        ('Skill', r'^milestone'),
        ('Skill', r'^code-review'),
        ('Skill', r'^pull-request'),

        ('Skill', r'^agentize:open-pr'),
        ('Skill', r'^agentize:open-issue'),
        ('Skill', r'^agentize:fork-dev-branch'),
        ('Skill', r'^agentize:commit-msg'),
        ('Skill', r'^agentize:review-standard'),
        ('Skill', r'^agentize:external-consensus'),
        ('Skill', r'^agentize:milestone'),
        ('Skill', r'^agentize:code-review'),
        ('Skill', r'^agentize:pull-request'),

        # WebSearch and WebFetch
        ('WebSearch', r'.*'),
        ('WebFetch', r'.*'),

        # File operations
        ('Write', r'.*'),
        ('Edit', r'.*'),
        ('Read', r'^/.*'),  # Allow reading any absolute path (deny rules filter secrets)

        # Search tools (read-only)
        ('Grep', r'.*'),
        ('Glob', r'.*'),
        ('LSP', r'.*'),

        # Task agents (exploration/research)
        ('Task', r'.*'),

        # User interaction tools
        ('TodoWrite', r'.*'),
        ('AskUserQuestion', r'.*'),

        # Bash - File operations
        ('Bash', r'^chmod \+x'),
        ('Bash', r'^test -f'),
        ('Bash', r'^test -d'),
        ('Bash', r'^date'),
        ('Bash', r'^echo'),
        ('Bash', r'^cat'),
        ('Bash', r'^head'),
        ('Bash', r'^tail'),
        ('Bash', r'^find'),
        ('Bash', r'^ls'),
        ('Bash', r'^wc'),
        ('Bash', r'^grep'),
        ('Bash', r'^rg'),
        ('Bash', r'^tree'),
        ('Bash', r'^tee'),
        ('Bash', r'^awk'),
        ('Bash', r'^xargs ls'),
        ('Bash', r'^xargs wc'),

        # Bash - Build tools
        ('Bash', r'^ninja'),
        ('Bash', r'^cmake'),
        ('Bash', r'^mkdir'),
        ('Bash', r'^make (all|build|check|lint|setup|test)'),

        # Bash - Test execution (project-neutral convention)
        ('Bash', r'^(\./)?tests/.*\.sh'),

        # Bash - Environment
        ('Bash', r'^module load'),

        # Bash - Git read operations
        ('Bash', r'^git (status|diff|log|show|rev-parse)'),

        # Bash - Git rebase to merge
        ('Bash', r'^git fetch (origin|upstream)'),
        ('Bash', r'^git rebase (origin|upstream) (main|master)'),
        ('Bash', r'^git rebase --continue'),

        # Bash - GitHub read operations
        ('Bash', r'^gh search'),
        ('Bash', r'^gh run (view|list)'),
        ('Bash', r'^gh pr (view|checks|list|diff|create)'),
        ('Bash', r'^gh issue (list|view|create)'),
        ('Bash', r'^gh label list'),
        ('Bash', r'^gh project (list|field-list|view|item-list)'),

        # Bash - External consensus script
        ('Bash', r'^\.claude/skills/external-consensus/scripts/external-consensus\.sh'),

        # Bash - Git write operations (more aggressive)
        ('Bash', r'^git add'),
        ('Bash', r'^git rm'),
        ('Bash', r'^git push'),
        ('Bash', r'^git commit'),

    ],
    'deny': [
        # Destructive operations
        ('Bash', r'^cd'),
        ('Bash', r'^rm -rf'),
        ('Bash', r'^sudo'),
        ('Bash', r'^git reset'),
        ('Bash', r'^git restore'),

        # Secret files
        ('Read', r'^\.env$'),
        ('Read', r'^\.env\.'),
        ('Read', r'.*/licenses/.*'),
        ('Read', r'.*/secrets?/.*'),
        ('Read', r'.*/config/credentials\.json$'),
        ('Read', r'/.*\.key$'),
        ('Read', r'.*\.pem$'),
    ],
}


def verify_force_push_to_own_branch(command: str) -> Optional[str]:
    """Check if force push targets the current branch (issue-* branches only).

    Returns 'allow' if pushing to own issue branch, 'deny' otherwise.
    This prevents accidentally/maliciously force pushing to others' branches.
    """
    # Match: git push --force/--force-with-lease/-f origin/upstream issue-*
    match = re.match(r'^git push (--force-with-lease|--force|-f) (origin|upstream) (issue-\S+)', command)
    if not match:
        return None  # Not a force push to issue branch

    target_branch = match.group(3)

    try:
        current_branch = subprocess.check_output(
            ['git', 'branch', '--show-current'],
            text=True,
            timeout=5
        ).strip()

        # Extract issue number from both branches (issue-42 or issue-42-title)
        target_issue = re.match(r'^issue-(\d+)', target_branch)
        current_issue = re.match(r'^issue-(\d+)', current_branch)

        if target_issue and current_issue:
            if target_issue.group(1) == current_issue.group(1):
                return 'allow'
            else:
                return 'deny'  # Pushing to different issue's branch

        return 'deny'  # Current branch is not an issue branch
    except Exception:
        return None  # Can't verify, let other rules handle it


def _find_config_paths(start_dir: Optional[Path] = None) -> tuple[Optional[Path], Optional[Path]]:
    """Locate .agentize.yaml and .agentize.local.yaml config files.

    Searches from start_dir up to parent directories.

    Args:
        start_dir: Directory to start searching from (default: current directory)

    Returns:
        Tuple of (project_path, local_path). Either may be None if not found.
    """
    if start_dir is None:
        start_dir = Path.cwd()

    start_dir = Path(start_dir).resolve()
    current = start_dir

    project_path = None
    local_path = None

    while True:
        project_candidate = current / ".agentize.yaml"
        local_candidate = current / ".agentize.local.yaml"

        if project_path is None and project_candidate.is_file():
            project_path = project_candidate
        if local_path is None and local_candidate.is_file():
            local_path = local_candidate

        # Stop if we found both or reached root
        if (project_path and local_path) or current.parent == current:
            break
        current = current.parent

    return project_path, local_path


def _parse_yaml_file(path: Path) -> dict:
    """Parse YAML file using PyYAML's safe_load.

    Args:
        path: Path to the YAML file

    Returns:
        Parsed configuration as nested dict
    """
    with open(path, "r") as f:
        return yaml.safe_load(f) or {}


def _extract_yaml_rules(config: dict, source: str) -> dict[str, list[tuple[str, str, str]]]:
    """Extract permission rules from a parsed config dict.

    Normalizes YAML rules to (tool, pattern, source) tuples.

    Args:
        config: Parsed config dict
        source: Source identifier ('project' or 'local')

    Returns:
        Dict with 'allow' and 'deny' lists of (tool, pattern, source) tuples
    """
    result: dict[str, list[tuple[str, str, str]]] = {'allow': [], 'deny': []}

    permissions = config.get('permissions', {})
    if not isinstance(permissions, dict):
        return result

    for decision in ['allow', 'deny']:
        items = permissions.get(decision, [])
        if not isinstance(items, list):
            continue

        for item in items:
            if isinstance(item, str):
                # String item: pattern only, tool defaults to Bash
                result[decision].append(('Bash', item, source))
            elif isinstance(item, dict):
                # Dict item: {pattern: "...", tool: "..."}
                pattern = item.get('pattern', '')
                tool = item.get('tool', 'Bash')
                if pattern:
                    result[decision].append((tool, pattern, source))

    return result


def _get_merged_rules(start_dir: Optional[Path] = None) -> dict[str, list[tuple[str, str, str]]]:
    """Get merged YAML rules from project and local configs.

    Uses mtime-based caching to avoid re-parsing unchanged files.

    Args:
        start_dir: Directory to start searching from

    Returns:
        Dict with 'allow' and 'deny' lists of (tool, pattern, source) tuples
    """
    global _yaml_rules_cache, _yaml_mtimes

    project_path, local_path = _find_config_paths(start_dir)

    # Check if cache is valid
    cache_valid = _yaml_rules_cache is not None
    paths_to_check = [(project_path, 'project'), (local_path, 'local')]

    for path, key in paths_to_check:
        if path is not None:
            try:
                current_mtime = path.stat().st_mtime
                cached_mtime = _yaml_mtimes.get(key, 0)
                if current_mtime != cached_mtime:
                    cache_valid = False
                    break
            except OSError:
                cache_valid = False
                break
        elif key in _yaml_mtimes:
            # File was removed
            cache_valid = False
            break

    if cache_valid and _yaml_rules_cache is not None:
        return _yaml_rules_cache

    # Rebuild cache
    result: dict[str, list[tuple[str, str, str]]] = {'allow': [], 'deny': []}
    _yaml_mtimes.clear()

    # Load project rules first
    if project_path is not None:
        try:
            config = _parse_yaml_file(project_path)
            rules = _extract_yaml_rules(config, 'project')
            result['allow'].extend(rules['allow'])
            result['deny'].extend(rules['deny'])
            _yaml_mtimes['project'] = project_path.stat().st_mtime
        except (OSError, ValueError):
            pass

    # Then local rules (appended after project rules)
    if local_path is not None:
        try:
            config = _parse_yaml_file(local_path)
            rules = _extract_yaml_rules(config, 'local')
            result['allow'].extend(rules['allow'])
            result['deny'].extend(rules['deny'])
            _yaml_mtimes['local'] = local_path.stat().st_mtime
        except (OSError, ValueError):
            pass

    _yaml_rules_cache = result
    return result


def clear_yaml_cache() -> None:
    """Clear the YAML rules cache.

    Used for testing to ensure fresh config loading.
    """
    global _yaml_rules_cache, _yaml_mtimes
    _yaml_rules_cache = None
    _yaml_mtimes.clear()


def match_rule(tool: str, target: str) -> Optional[tuple]:
    """Match tool and target against permission rules.

    Checks hardcoded rules first, then YAML-configured rules.
    Hardcoded deny rules always take precedence over YAML allows.

    Args:
        tool: Tool name (e.g., 'Bash', 'Read')
        target: Normalized target string

    Returns:
        (decision, source) if matched, None if no match.
        Source is 'rules:hardcoded', 'rules:project', 'rules:local', or 'force-push-verify'.
    """
    # Special check: force push to issue branches requires current branch verification
    if tool == 'Bash':
        force_push_result = verify_force_push_to_own_branch(target)
        if force_push_result is not None:
            return (force_push_result, 'force-push-verify')

    # Load YAML rules
    yaml_rules = _get_merged_rules()

    # Check rules in priority order: deny -> ask -> allow
    # 1. Hardcoded deny rules (always win)
    for rule_tool, pattern in PERMISSION_RULES.get('deny', []):
        if rule_tool == tool:
            try:
                if re.search(pattern, target):
                    return ('deny', 'rules:hardcoded')
            except re.error:
                continue

    # 2. YAML deny rules
    for rule_tool, pattern, source in yaml_rules.get('deny', []):
        if rule_tool == tool:
            try:
                if re.search(pattern, target):
                    return ('deny', f'rules:{source}')
            except re.error:
                continue

    # 3. Hardcoded ask rules
    for rule_tool, pattern in PERMISSION_RULES.get('ask', []):
        if rule_tool == tool:
            try:
                if re.search(pattern, target):
                    return ('ask', 'rules:hardcoded')
            except re.error:
                continue

    # 4. Hardcoded allow rules
    for rule_tool, pattern in PERMISSION_RULES.get('allow', []):
        if rule_tool == tool:
            try:
                if re.search(pattern, target):
                    return ('allow', 'rules:hardcoded')
            except re.error:
                continue

    # 5. YAML allow rules
    for rule_tool, pattern, source in yaml_rules.get('allow', []):
        if rule_tool == tool:
            try:
                if re.search(pattern, target):
                    return ('allow', f'rules:{source}')
            except re.error:
                continue

    return None
