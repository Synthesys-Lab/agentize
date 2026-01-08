"""Permission rules for tool usage.

This module defines PERMISSION_RULES and provides rule matching logic.
Priority: deny -> ask -> allow (first match wins)
"""

import re
import subprocess
from typing import Optional

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

        # WebSearch and WebFetch
        ('WebSearch', r'.*'),
        ('WebFetch', r'.*'),

        # File operations
        ('Write', r'.*'),
        ('Edit', r'.*'),
        ('Read', r'^/.*'),  # Allow reading any absolute path (deny rules filter secrets)

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
    'ask': [
        # General commands
        ('Bash', r'^python3'),
        ('Bash', r'^test(?!\s+-[fd])'),  # test without -f or -d flags

        # GitHub write operations
        ('Bash', r'^gh api'),
        ('Bash', r'^gh project item-edit'),
    ]
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


def match_rule(tool: str, target: str) -> Optional[tuple]:
    """Match tool and target against PERMISSION_RULES.

    Args:
        tool: Tool name (e.g., 'Bash', 'Read')
        target: Normalized target string

    Returns:
        (decision, 'rules') if matched, None if no match
    """
    # Special check: force push to issue branches requires current branch verification
    if tool == 'Bash':
        force_push_result = verify_force_push_to_own_branch(target)
        if force_push_result is not None:
            return (force_push_result, 'force-push-verify')

    # Check rules in priority order: deny -> ask -> allow
    for decision in ['deny', 'ask', 'allow']:
        for rule_tool, pattern in PERMISSION_RULES.get(decision, []):
            if rule_tool == tool:
                try:
                    if re.search(pattern, target):
                        return (decision, 'rules')
                except re.error:
                    # Malformed pattern, skip
                    continue

    return None
