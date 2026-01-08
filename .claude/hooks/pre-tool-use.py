#!/usr/bin/env python3

import sys
import json
import os
import datetime
import re

# This hook logs tools used in HANDSOFF_MODE and enforces permission rules.

# Permission rules: (tool_name, regex_pattern)
# Priority: deny → ask → allow (first match wins)
PERMISSION_RULES = {
    'allow': [
        # Skills
        ('Skill', r'^open-pr$'),
        ('Skill', r'^open-issue$'),
        ('Skill', r'^fork-dev-branch$'),
        ('Skill', r'^commit-msg$'),
        ('Skill', r'^review-standard$'),
        ('Skill', r'^external-consensus$'),
        ('Skill', r'^milestone$'),
        ('Skill', r'^code-review$'),
        ('Skill', r'^pull-request$'),

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
        # Git write operations
        ('Bash', r'^git checkout'),

        # General commands
        ('Bash', r'^python3'),
        ('Bash', r'^test(?!\s+-[fd])'),  # test without -f or -d flags

        # GitHub write operations
        ('Bash', r'^gh api'),
        ('Bash', r'^gh project item-edit'),
    ]
}

def strip_env_vars(command):
    """Strip leading ENV=value pairs from bash commands."""
    # Match one or more ENV=value patterns at the start
    env_pattern = re.compile(r'^(\w+=\S+\s+)+')
    return env_pattern.sub('', command)

def check_permission(tool, target):
    """
    Check permission for tool usage against PERMISSION_RULES.
    Returns: 'allow', 'deny', or 'ask'
    Priority: deny → ask → allow (first match wins)
    Default: 'ask' if no match or error
    """
    try:
        # Special handling for Bash: strip environment variables
        if tool == 'Bash':
            target = strip_env_vars(target)

        # Check rules in priority order: deny → ask → allow
        for decision in ['deny', 'ask', 'allow']:
            for rule_tool, pattern in PERMISSION_RULES.get(decision, []):
                if rule_tool == tool:
                    try:
                        if re.search(pattern, target):
                            return decision
                    except re.error:
                        # Malformed pattern, fail safe to 'ask'
                        continue

        # No match, default to 'ask'
        return 'ask'
    except Exception:
        # Any error, fail safe to 'ask'
        return 'ask'

hook_input = json.load(sys.stdin)

tool = hook_input['tool_name']
session = hook_input['session_id']
tool_input = hook_input.get('tool_input', {})

# Extract relevant object/target from tool_input
target = ''
if tool in ['Read', 'Write', 'Edit', 'NotebookEdit']:
    target = tool_input.get('file_path', '')
elif tool == 'Bash':
    target = tool_input.get('command', '')
elif tool == 'Grep':
    pattern = tool_input.get('pattern', '')
    path = tool_input.get('path', '')
    target = f'pattern={pattern}' + (f' path={path}' if path else '')
elif tool == 'Glob':
    pattern = tool_input.get('pattern', '')
    path = tool_input.get('path', '')
    target = f'pattern={pattern}' + (f' path={path}' if path else '')
elif tool == 'Task':
    subagent = tool_input.get('subagent_type', '')
    desc = tool_input.get('description', '')
    target = f'subagent={subagent} desc={desc}'
elif tool == 'Skill':
    skill = tool_input.get('skill', '')
    args = tool_input.get('args', '')
    target = skill + (f' {args}' if args else '')
elif tool == 'WebFetch':
    url = tool_input.get('url', '')
    target = url
elif tool == 'WebSearch':
    query = tool_input.get('query', '')
    target = f'query={query}'
elif tool == 'LSP':
    op = tool_input.get('operation', '')
    file_path = tool_input.get('filePath', '')
    line = tool_input.get('line', '')
    target = f'op={op} file={file_path}:{line}'
elif tool == 'AskUserQuestion':
    questions = tool_input.get('questions', [])
    if questions:
        headers = [q.get('header', '') for q in questions]
        target = f'questions={",".join(headers)}'
elif tool == 'TodoWrite':
    todos = tool_input.get('todos', [])
    target = f'todos={len(todos)}'
else:
    # For other tools, try to get a representative field
    target = str(tool_input)[:100]

# Check permission
permission_decision = check_permission(tool, target)

if os.getenv('HANDSOFF_MODE', '0').lower() in ['1', 'true', 'on', 'enable'] and \
   os.getenv('HANDSOFF_DEBUG', '0').lower() in ['1', 'true', 'on', 'enable']:
    os.makedirs('.tmp', exist_ok=True)
    os.makedirs('.tmp/hooked-sessions', exist_ok=True)

    # Detect workflow state from session state file
    workflow = 'unknown'
    state_file = f'.tmp/hooked-sessions/{session}.json'
    if os.path.exists(state_file):
        try:
            with open(state_file, 'r') as f:
                state = json.load(f)
                workflow_type = state.get('workflow', '')
                if workflow_type == 'ultra-planner':
                    workflow = 'plan'
                elif workflow_type == 'issue-to-impl':
                    workflow = 'impl'
        except (json.JSONDecodeError, Exception):
            pass

    # Log tool usage
    time = datetime.datetime.now().isoformat()
    with open('.tmp/hooked-sessions/tool-used.txt', 'a') as f:
        f.write(f'[{time}] [{session}] [{workflow}] {tool} | {target}\n')

output = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": permission_decision
    }
}
print(json.dumps(output))