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
# Continuation prompt templates
# ============================================================

_CONTINUATION_PROMPTS = {
    ULTRA_PLANNER: '''This is an auto-continuation prompt for handsoff mode, it is currently {count}/{max_count} continuations.
The ultimate goal of this workflow is to create a comprehensive plan and post it on GitHub Issue. Have you delivered this?
1. If not, please continue! Try to be as hands-off as possible, avoid asking user design decision questions, and choose the option you recommend most.
2. If you have already delivered the plan, manually stop further continuations.
3. If you do not know what to do next, or you reached the max continuations limit without delivering the plan,
   look at the current branch name to see what issue you are working on. Then stop manually
   and leave a comment on the GitHub Issue for human collaborators to take over.
   This comment shall include:
    - What you have done so far
    - What is blocking you from moving forward
    - What kind of help you need from human collaborators
    - The session ID: {session_id} so that human can `claude -r {session_id}` for a human intervention.
4. To stop further continuations, run:
   jq '.state = "done"' {fname} > {fname}.tmp && mv {fname}.tmp {fname}
5. When creating issues or PRs, use `--body-file` instead of `--body`, as body content with "--something" will be misinterpreted as flags.''',

    ISSUE_TO_IMPL: '''This is an auto-continuation prompt for handsoff mode, it is currently {count}/{max_count} continuations.
The ultimate goal of this workflow is to deliver a PR on GitHub that implements the corresponding issue. Did you have this delivered?
1. If you have completed a milestone but still have more to do, please continue on the next milestone!
{plan_context}1.5. If you are working on documentation updates (Step 5):
   - Review the "Documentation Planning" section in the issue for diff specifications
   - Apply any markdown diff previews provided in the plan
   - Create a dedicated [docs] commit before proceeding to tests
2. If you have every coding task done, start the following steps to prepare for PR:
   2.0 Rebase the branch with upstream or origin (priority: upstream/main > upstream/master > origin/main > origin/master).
   2.1 Run the full test suite following the project's test conventions (see CLAUDE.md).
   2.2 Use the code-quality-reviewer agent to review the code quality.
   2.3 If the code review raises concerns, fix the issues and return to 2.1.
   2.4 If the code review is satisfactory, proceed to open the PR.
3. Prepare and create the PR. Do not ask user "Should I create the PR?" - just go ahead and create it!
   - Creating the PR should use the `/open-pr` skill with appropriate titles.
4. If the PR is successfully created, manually stop further continuations.
5. If you do not know what to do next, or you reached the max continuations limit without delivering the PR,
   manually stop further continuations and look at the current branch name to see what issue you are working on.
   Then, leave a comment on the GitHub Issue for human collaborators to take over.
   This comment shall include:
  - What you have done so far
  - What is blocking you from moving forward
  - What kind of help you need from human collaborators
  - The session ID: {session_id} so that human can `claude -r {session_id}` for a human intervention.
6. To stop further continuations, run:
   jq '.state = "done"' {fname} > {fname}.tmp && mv {fname}.tmp {fname}
7. When creating issues or PRs, use `--body-file` instead of `--body`, as body content with "--something" will be misinterpreted as flags.''',

    PLAN_TO_ISSUE: '''This is an auto-continuation prompt for handsoff mode, it is currently {count}/{max_count} continuations.
The ultimate goal of this workflow is to create a GitHub [plan] issue from the user-provided plan.

1. If you have not yet created the GitHub issue, please continue working on it!
   - Parse and format the plan content appropriately
   - Create the issue with proper labels and formatting
   - Use `--body-file` instead of `--body` to avoid flag parsing issues
2. If you have successfully created the GitHub issue, manually stop further continuations.
3. If you are blocked or reached the max continuations limit without creating the issue:
   - Stop manually and inform the user what happened
   - Include what you have done so far
   - Include what is blocking you
   - Include the session ID: {session_id} so that human can `claude -r {session_id}` for intervention.
4. To stop further continuations, run:
   jq '.state = "done"' {fname} > {fname}.tmp && mv {fname}.tmp {fname}''',

    SETUP_VIEWBOARD: '''This is an auto-continuation prompt for handsoff mode, it is currently {count}/{max_count} continuations.
The ultimate goal of this workflow is to set up a GitHub Projects v2 board. Have you completed all steps?
1. If not, please continue with the remaining setup steps!
2. If setup is complete, manually stop further continuations.
3. To stop further continuations, run:
   jq '.state = "done"' {fname} > {fname}.tmp && mv {fname}.tmp {fname}''',

    SYNC_MASTER: '''This is an auto-continuation prompt for handsoff mode, it is currently {count}/{max_count} continuations.
The ultimate goal of this workflow is to sync the local main/master branch with upstream and force-push the PR branch.

1. Check if the rebase has completed successfully:
   - Run `git status` to verify the working tree state
   - If rebase conflicts are detected, resolve them and run `git rebase --continue`
   - If rebase was aborted, re-run the sync-master workflow from the beginning
2. After successful rebase, verify the PR number is available: {pr_no}
   - If PR number is 'unknown', check the current branch name for the PR association
3. Force-push the rebased branch to update the PR:
   - Run `git push -f` to push the rebased changes
   - Verify the push succeeded without errors
4. After successful push, manually stop further continuations.
5. If you encounter unresolvable conflicts or errors:
   - Stop manually and inform the user what happened
   - Include what you have done so far
   - Include what is blocking you
   - Include the session ID: {session_id} so that human can `claude -r {session_id}` for intervention.
6. To stop further continuations, run:
   jq '.state = "done"' {fname} > {fname}.tmp && mv {fname}.tmp {fname}''',
}


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
    workflow_template = _CONTINUATION_PROMPTS.get(workflow, '')
    if not workflow_template:
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
    return workflow in _CONTINUATION_PROMPTS


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

    # Fall back to static template (existing behavior)
    template = _CONTINUATION_PROMPTS.get(workflow, '')
    if not template:
        return ''

    # Build plan context for issue-to-impl workflow
    plan_context = ''
    if workflow == ISSUE_TO_IMPL and plan_path:
        plan_context = f'''1.5. Review the cached plan (if available):
   - Plan file: {plan_path}
'''
        if plan_excerpt:
            plan_context += f'   {plan_excerpt}\n'

    return template.format(
        session_id=session_id,
        fname=fname,
        count=count,
        max_count=max_count,
        pr_no=pr_no,
        plan_context=plan_context,
    )
