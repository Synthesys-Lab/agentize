"""Unified workflow definitions for handsoff mode.

This module centralizes workflow detection, issue extraction, and continuation
prompts for all supported handsoff workflows. Adding a new workflow requires
editing only this file.

Supported workflows:
- /ultra-planner: Multi-agent debate-based planning
- /issue-to-impl: Complete development cycle from issue to PR
- /plan-to-issue: Create GitHub [plan] issues from user-provided plans
- /setup-viewboard: GitHub Projects v2 board setup
- /sync-master: Sync local main/master with upstream
"""

import re
import os
import subprocess
import json
from typing import Optional
from datetime import datetime

# ============================================================
# Workflow name constants
# ============================================================

ULTRA_PLANNER = 'ultra-planner'
ISSUE_TO_IMPL = 'issue-to-impl'
PLAN_TO_ISSUE = 'plan-to-issue'
SETUP_VIEWBOARD = 'setup-viewboard'
SYNC_MASTER = 'sync-master'

# ============================================================
# Command to workflow mapping
# ============================================================

WORKFLOW_COMMANDS = {
    '/ultra-planner': ULTRA_PLANNER,
    '/issue-to-impl': ISSUE_TO_IMPL,
    '/plan-to-issue': PLAN_TO_ISSUE,
    '/setup-viewboard': SETUP_VIEWBOARD,
    '/sync-master': SYNC_MASTER,
}

# ============================================================
# Supported workflow types for template loading
# ============================================================

_SUPPORTED_WORKFLOWS = {ULTRA_PLANNER, ISSUE_TO_IMPL, PLAN_TO_ISSUE, SETUP_VIEWBOARD, SYNC_MASTER}


def _load_prompt_template(workflow_type: str) -> str:
    """Load a continuation prompt template from external file.

    Args:
        workflow_type: Workflow name (e.g., 'ultra-planner', 'issue-to-impl')

    Returns:
        Template string with {#variable#} placeholders

    Raises:
        FileNotFoundError: If template file does not exist
    """
    # Determine the prompts directory relative to this module
    module_dir = os.path.dirname(os.path.abspath(__file__))
    prompts_dir = os.path.join(os.path.dirname(module_dir), 'prompts')
    template_path = os.path.join(prompts_dir, f'{workflow_type}.txt')

    if not os.path.isfile(template_path):
        raise FileNotFoundError(f"Template file not found: {template_path}")

    with open(template_path, 'r') as f:
        return f.read()


# ============================================================
# AI Supervisor functions (for dynamic continuation prompts)
# ============================================================

def _log_supervisor_debug(message: dict):
    """Log supervisor activity to hook-debug.log for debugging.

    Args:
        message: Dictionary with debug information
    """
    try:
        agentize_home = os.getenv('AGENTIZE_HOME', os.path.expanduser('~/.agentize'))
        debug_log = os.path.join(agentize_home, '.tmp', 'hook-debug.log')

        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(debug_log), exist_ok=True)

        # Add timestamp
        message['timestamp'] = datetime.now().isoformat()

        # Append to log file
        with open(debug_log, 'a') as f:
            f.write(json.dumps(message) + '\n')
    except Exception:
        pass  # Silently ignore logging errors


def _ask_claude_for_guidance(workflow: str, continuation_count: int,
                             max_continuations: int, transcript_path: str = None) -> Optional[str]:
    """Ask Claude for context-aware continuation guidance.

    Follows the same subprocess pattern as permission/determine.py's approach.
    Returns None on failure (fallback to static template).

    Args:
        workflow: Workflow name string
        continuation_count: Current continuation count
        max_continuations: Maximum continuations allowed
        transcript_path: Optional path to JSONL transcript file for conversation context

    Returns:
        Dynamic prompt from Claude, or None to use static template
    """
    if os.getenv('HANDSOFF_SUPERVISOR', '0').lower() not in ['1', 'true', 'on']:
        return None  # Feature disabled

    # Read transcript if available for conversation context
    transcript_context = ""
    transcript_entries = []
    if transcript_path and os.path.isfile(transcript_path):
        try:
            transcript_lines = []
            with open(transcript_path, 'r') as f:
                for line in f:
                    if line.strip():
                        entry = json.loads(line)
                        # Extract role and content from transcript entry
                        if 'role' in entry and 'content' in entry:
                            transcript_lines.append(f"{entry['role']}: {entry['content'][:200]}")
                            transcript_entries.append(entry)

            if transcript_lines:
                # Include last 5 transcript entries for context
                recent_context = "\n".join(transcript_lines[-5:])
                transcript_context = f"\n\nRECENT CONVERSATION CONTEXT:\n{recent_context}"
        except Exception:
            pass  # Silently ignore transcript read errors

    # Get the full prompt template for this workflow
    try:
        workflow_template = _load_prompt_template(workflow)
    except FileNotFoundError:
        return None  # No template for this workflow

    # Build context prompt for Claude with full workflow template
    prompt = f'''You are a workflow supervisor for an AI agent system.

WORKFLOW: {workflow}
PROGRESS: {continuation_count} / {max_continuations} continuations

WORKFLOW PROMPT TEMPLATE (this is what the agent receives as instructions):
---
{workflow_template}
---
{transcript_context}

Based on the workflow template above and the conversation context, provide a concise instruction for what the agent should do next.

Respond with ONLY the continuation instruction (2-3 sentences), no explanations.'''

    # Log the request
    _log_supervisor_debug({
        'event': 'supervisor_request',
        'workflow': workflow,
        'continuation_count': continuation_count,
        'max_continuations': max_continuations,
        'transcript_path': transcript_path,
        'transcript_entries_count': len(transcript_entries),
        'prompt': prompt[:500]  # Log first 500 chars
    })

    # Invoke Claude subprocess (similar to determine.py pattern)
    try:
        result = subprocess.check_output(
            ['claude', '-p'],
            input=prompt,
            text=True,
            timeout=900  # 15 minute timeout for prompt response
        )
        guidance = result.strip()
        if guidance:
            _log_supervisor_debug({
                'event': 'supervisor_success',
                'workflow': workflow,
                'guidance': guidance[:500]  # Log first 500 chars
            })
            return guidance
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, Exception) as e:
        # Log error for debugging but don't break workflow
        error_msg = str(e)[:200]
        _log_supervisor_debug({
            'event': 'supervisor_error',
            'workflow': workflow,
            'error_type': type(e).__name__,
            'error_message': error_msg
        })

        # Try to log via logger if available
        try:
            from lib.logger import logger
            logger('supervisor', f'Claude guidance failed: {error_msg}')
        except Exception:
            pass  # Silently ignore if logger import fails
        return None

    return None


# ============================================================
# Public functions
# ============================================================

def detect_workflow(prompt):
    """Detect workflow from command prompt.

    Args:
        prompt: The user's input prompt

    Returns:
        Workflow name string if detected, None otherwise
    """
    for command, workflow in WORKFLOW_COMMANDS.items():
        if prompt.startswith(command):
            return workflow
    return None


def extract_issue_no(prompt):
    """Extract issue number from workflow command arguments.

    Patterns:
    - /issue-to-impl <number>
    - /ultra-planner --refine <number>
    - /ultra-planner --from-issue <number>

    Args:
        prompt: The user's input prompt

    Returns:
        Issue number as int, or None if not found
    """
    # Pattern for /issue-to-impl <number>
    match = re.match(r'^/issue-to-impl\s+(\d+)', prompt)
    if match:
        return int(match.group(1))

    # Pattern for /ultra-planner --refine <number>
    match = re.search(r'--refine\s+(\d+)', prompt)
    if match:
        return int(match.group(1))

    # Pattern for /ultra-planner --from-issue <number>
    match = re.search(r'--from-issue\s+(\d+)', prompt)
    if match:
        return int(match.group(1))

    return None


def extract_pr_no(prompt):
    """Extract PR number from /sync-master command arguments.

    Pattern:
    - /sync-master <number>

    Args:
        prompt: The user's input prompt

    Returns:
        PR number as int, or None if not found
    """
    match = re.match(r'^/sync-master\s+(\d+)', prompt)
    if match:
        return int(match.group(1))
    return None


def has_continuation_prompt(workflow):
    """Check if a workflow has a continuation prompt defined.

    Args:
        workflow: Workflow name string

    Returns:
        True if workflow has continuation prompt, False otherwise
    """
    return workflow in _SUPPORTED_WORKFLOWS


def get_continuation_prompt(workflow, session_id, fname, count, max_count, pr_no='unknown', transcript_path=None, plan_path=None, plan_excerpt=None):
    """Get formatted continuation prompt for a workflow.

    Optionally uses Claude for dynamic guidance if HANDSOFF_SUPERVISOR is enabled.
    Falls back to static templates on any error.

    Args:
        workflow: Workflow name string
        session_id: Current session ID
        fname: Path to session state file
        count: Current continuation count
        max_count: Maximum continuations allowed
        pr_no: PR number (only used for sync-master workflow)
        transcript_path: Optional path to JSONL transcript for Claude context
        plan_path: Optional path to cached plan file (for issue-to-impl workflow)
        plan_excerpt: Optional excerpt from cached plan (for issue-to-impl workflow)

    Returns:
        Formatted continuation prompt string, or empty string if workflow not found
    """
    # Try to get dynamic guidance from Claude if enabled
    guidance = _ask_claude_for_guidance(workflow, count, max_count, transcript_path)
    if guidance:
        return guidance

    # Fall back to static template from external file
    try:
        template = _load_prompt_template(workflow)
    except FileNotFoundError:
        return ''

    # Build plan context for issue-to-impl workflow
    plan_context = ''
    if workflow == ISSUE_TO_IMPL and plan_path:
        plan_context = f'''1.5. Review the cached plan (if available):
   - Plan file: {plan_path}
'''
        if plan_excerpt:
            plan_context += f'   {plan_excerpt}\n'

    # Apply variable substitution using str.replace() with {#var#} syntax
    return (template
            .replace('{#session_id#}', session_id or 'N/A')
            .replace('{#fname#}', fname or 'N/A')
            .replace('{#continuations#}', str(count))
            .replace('{#max_continuations#}', str(max_count))
            .replace('{#pr_no#}', str(pr_no) if pr_no else 'N/A')
            .replace('{#plan_context#}', plan_context))
