#!/usr/bin/env python3

import sys
import json
import os
import datetime
import re
import subprocess
from logger import log_tool_decision

# This hook logs tools used in HANDSOFF_MODE and enforces permission rules.

# Permission rules: (tool_name, regex_pattern)
# Priority: deny → ask → allow (first match wins)
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

def strip_env_vars(command):
    """Strip leading ENV=value pairs from bash commands."""
    # Match one or more ENV=value patterns at the start
    env_pattern = re.compile(r'^(\w+=\S+\s+)+')
    return env_pattern.sub('', command)

def strip_shell_prefixes(command):
    """Strip leading shell option prefixes from bash commands.

    Common prefixes like 'set -x && ' or 'set -e && ' are debugging/safety
    options that don't change command semantics for permission purposes.
    """
    # Match patterns like: set -x && , set -e && , set -o pipefail &&
    prefix_pattern = re.compile(r'^(set\s+-[exo]\s+[a-z]*\s*&&\s*)+', re.IGNORECASE)
    return prefix_pattern.sub('', command)

def ask_haiku_first(tool, target):
    global hook_input

    if os.getenv('HANDSOFF_AUTO_PERMISSION', '0').lower() not in ['1', 'true', 'on', 'enable']:
        log_tool_decision(hook_input.get('session_id', 'unknown'), '', tool, target, 'SKIP_HAIKU')
        return 'ask'

    transcript_path = hook_input.get("transcript_path", "")

    # Read last line from JSONL transcript
    try:
        with open(transcript_path, 'r') as f:
            transcript = f.readlines()[-1]
    except Exception as e:
        log_tool_decision(hook_input.get('session_id', 'unknown'), '', tool, target, f'ERROR transcript: {str(e)}')
        return 'ask'

    prompt = f'''You are a judger for the below Claude Code tool usage.
Determine the risk of implicitly automatically run this command below.
Give 'allow' for low or no-risk cases.
Give 'deny' for absolutely high risk cases.
Give 'ask' for what you are not sure.
Do not output anything else.

Here is context of the tool usage:
{transcript}

Besides the tool itself, if it is a script execution, consider to look into the script content too.

Tool: {tool}
Target: {target}
'''

    try:
        result = subprocess.check_output(
            ['claude', '--model', 'haiku', '-p'],
            input=prompt,
            text=True,
            timeout=30
        )
        full_response = result.strip()
        # Extract only the first word from the response
        decision = full_response.split()[0].lower() if full_response else ''

        # Log the full Haiku response for debugging
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'HAIKU: {full_response}')

        if decision in ['allow', 'deny', 'ask']:
            return decision
        else:
            # Log invalid output error
            log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR invalid_output: {decision}')
            return 'ask'
    except subprocess.TimeoutExpired as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR timeout: {str(e)}')
        return 'ask'
    except subprocess.CalledProcessError as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR process: returncode={e.returncode} stderr={e.stderr}')
        return 'ask'
    except Exception as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR subprocess: {str(e)}')
        return 'ask'

def normalize_bash_command(command):
    """Normalize bash command by stripping env vars and shell prefixes."""
    command = strip_env_vars(command)
    command = strip_shell_prefixes(command)
    return command

def check_permission(tool, target, raw_target):
    """
    Check permission for tool usage against PERMISSION_RULES.
    Returns: (decision, source) where decision is 'allow'/'deny'/'ask' and source is 'rules' or 'haiku'
    Priority: deny → ask → allow (first match wins)
    Default: ask Haiku if no match or error

    Args:
        tool: Tool name
        target: Normalized target (for rule matching)
        raw_target: Original target (for logging/Haiku context)
    """
    try:
        # Check rules in priority order: deny → ask → allow
        for decision in ['deny', 'ask', 'allow']:
            for rule_tool, pattern in PERMISSION_RULES.get(decision, []):
                if rule_tool == tool:
                    try:
                        if re.search(pattern, target):
                            return (decision, 'rules')
                    except re.error:
                        # Malformed pattern, fail safe to 'ask'
                        continue

        # No match, ask Haiku (use raw_target for context)
        haiku_decision = ask_haiku_first(tool, raw_target)
        return (haiku_decision, 'haiku')
    except Exception as e:
        # Any error, ask Haiku as fallback
        try:
            haiku_decision = ask_haiku_first(tool, raw_target)
            return (haiku_decision, 'haiku')
        except Exception:
            # If even Haiku fails, default to 'ask'
            return ('ask', 'error')

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

# Keep raw_target for logging, normalize target for permission checking
raw_target = target
if tool == 'Bash':
    target = normalize_bash_command(target)

# Check permission
permission_decision, decision_source = check_permission(tool, target, raw_target)

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

    # Log tool usage - separate files for rules vs haiku decisions
    # Use raw_target for logging to preserve original command
    time = datetime.datetime.now().isoformat()
    if decision_source == 'rules' and permission_decision == 'allow':
        # Automatically approved tools go to tool-used.txt
        with open('.tmp/hooked-sessions/tool-used.txt', 'a') as f:
            f.write(f'[{time}] [{session}] [{workflow}] {tool} | {raw_target}\n')
    elif decision_source == 'haiku':
        # Haiku-determined tools go to their own file
        with open('.tmp/hooked-sessions/tool-haiku-determined.txt', 'a') as f:
            f.write(f'[{time}] [{session}] [{workflow}] [{permission_decision}] {tool} | {raw_target}\n')

output = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": permission_decision
    }
}
print(json.dumps(output))