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

Self-contained design:
- This module provides its own `_get_agentize_home()` and `_run_acw()` helpers
- These invoke the `acw` shell function by sourcing `src/cli/acw.sh` directly
- No imports from `agentize.shell` or dependency on `setup.sh`
- Maintains plugin standalone capability for handsoff supervisor workflows
"""

import re
import os
import subprocess
import json
import tempfile
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
# AI Supervisor configuration
# ============================================================

# Valid supervisor providers
_VALID_PROVIDERS = {'claude', 'codex', 'cursor', 'opencode'}

# Default models per provider
_DEFAULT_MODELS = {
    'claude': 'opus',
    'codex': 'gpt-5.2-codex',
    'cursor': 'gpt-5.2-codex-xhigh',
    'opencode': 'openai/gpt-5.2-codex'
}

# Legacy boolean mappings for backward compatibility
_LEGACY_DISABLE = {'0', 'false', 'off', 'no', 'disable', 'disabled'}
_LEGACY_ENABLE = {'1', 'true', 'on', 'yes', 'enable', 'enabled'}


def _get_supervisor_provider() -> Optional[str]:
    """Get the supervisor provider from environment.

    Supports both new provider names and legacy boolean values for
    backward compatibility.

    Returns:
        Provider name ('claude', 'codex', 'cursor', 'opencode') or None if disabled
    """
    value = os.getenv('HANDSOFF_SUPERVISOR', 'none').lower().strip()

    # Check for explicit 'none' or empty
    if value in ('none', ''):
        return None

    # Check for valid provider name
    if value in _VALID_PROVIDERS:
        return value

    # Backward compatibility: legacy boolean disable values
    if value in _LEGACY_DISABLE:
        return None

    # Backward compatibility: legacy boolean enable values → default to claude
    if value in _LEGACY_ENABLE:
        return 'claude'

    # Unknown value - treat as disabled and log warning
    return None


def _get_supervisor_model(provider: str) -> str:
    """Get the model name for the supervisor provider.

    Args:
        provider: Provider name ('claude', 'codex', 'cursor', 'opencode')

    Returns:
        Model name from HANDSOFF_SUPERVISOR_MODEL or provider default
    """
    return os.getenv('HANDSOFF_SUPERVISOR_MODEL', _DEFAULT_MODELS.get(provider, 'sonnet'))


def _get_supervisor_flags() -> str:
    """Get extra flags to pass to acw.

    Returns:
        Value of HANDSOFF_SUPERVISOR_FLAGS or empty string
    """
    return os.getenv('HANDSOFF_SUPERVISOR_FLAGS', '')


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


def _ask_supervisor_for_guidance(workflow: str, continuation_count: int,
                                 max_continuations: int, transcript_path: str = None) -> Optional[str]:
    """Ask AI provider for context-aware continuation guidance.

    Uses acw (Agent CLI Wrapper) to invoke the configured AI provider.
    Returns None on failure (fallback to static template).

    Args:
        workflow: Workflow name string
        continuation_count: Current continuation count
        max_continuations: Maximum continuations allowed
        transcript_path: Optional path to JSONL transcript file for conversation context

    Returns:
        Dynamic prompt from provider, or None to use static template
    """
    provider = _get_supervisor_provider()
    if provider is None:
        return None  # Supervisor disabled

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

    # Build context prompt for supervisor with full workflow template
    prompt = f'''You are a workflow supervisor for an AI agent system.
You are evaluating an exisint `host session` to see:
1. If it is sticking to the original purpose of the workflow.
2. If it is making progress towards completing the workflow.
3. What the next best steps are to continue progress.

Based on the given workflow template and the conversation context, provide clear, comprehensive,
and instructions for what the agent should do next.

If the workflow is done, use instruct the host agent to use the command below to end the auto-continuation:

# Input:

WORKFLOW: {workflow}

PROGRESS: {continuation_count} / {max_continuations} continuations

WORKFLOW PROMPT TEMPLATE (this is what the agent receives as instructions):
{workflow_template}

---
{transcript_context}

# Output:

1. If it is not sticking to the original purpose, provide corrective instructions to get back on track.
2. If it sticks to the original purpose of the workflow, clearly state what to do next.
3. If the goal is complete, ask the host session to use the command below to mark the workflow as done:
    jq '.state = "done"' {{#fname#}} > {{#fname#}}.tmp && mv {{#fname#}}.tmp {{#fname#}}
4. No matter creating a Issue or PR, always as the host session to use `--body-file` to provide detailed descriptions,
   as embedded `--` in `--body` may confuse the CLI parser.

'''


    # Get provider configuration
    model = _get_supervisor_model(provider)
    extra_flags = _get_supervisor_flags()

    # Log the request
    _log_supervisor_debug({
        'event': 'supervisor_request',
        'workflow': workflow,
        'provider': provider,
        'model': model,
        'continuation_count': continuation_count,
        'max_continuations': max_continuations,
        'transcript_path': transcript_path,
        'transcript_entries_count': len(transcript_entries),
        'prompt': prompt[:500]  # Log first 500 chars
    })

    # Invoke acw via subprocess with temp files for I/O
    input_file = None
    output_file = None
    try:
        # Create temp files for acw I/O
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(prompt)
            input_file = f.name

        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            output_file = f.name

        # Build acw command
        # acw <provider> <model> <input-file> <output-file> [options...]
        cmd = ['acw', provider, model, input_file, output_file]
        if extra_flags:
            # Split extra flags and append (handles flags like "--timeout 1800")
            cmd.extend(extra_flags.split())

        _log_supervisor_debug({
            'event': 'supervisor_acw_command',
            'cmd': ' '.join(cmd)
        })

        # Run acw command
        subprocess.run(
            cmd,
            timeout=900,  # 15 minute timeout for prompt response
            check=True,
            capture_output=True,
            text=True
        )

        # Read result from output file
        with open(output_file, 'r') as f:
            guidance = f.read().strip()

        if guidance:
            _log_supervisor_debug({
                'event': 'supervisor_success',
                'workflow': workflow,
                'provider': provider,
                'guidance': guidance[:500]  # Log first 500 chars
            })
            return guidance

    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, Exception) as e:
        # Log error for debugging but don't break workflow
        error_msg = str(e)[:200]
        _log_supervisor_debug({
            'event': 'supervisor_error',
            'workflow': workflow,
            'provider': provider,
            'error_type': type(e).__name__,
            'error_message': error_msg
        })

        # Try to log via logger if available
        try:
            from lib.logger import logger
            logger('supervisor', f'{provider} guidance failed: {error_msg}')
        except Exception:
            pass  # Silently ignore if logger import fails
        return None

    finally:
        # Clean up temp files
        if input_file and os.path.exists(input_file):
            try:
                os.unlink(input_file)
            except Exception:
                pass
        if output_file and os.path.exists(output_file):
            try:
                os.unlink(output_file)
            except Exception:
                pass

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
    # Try to get dynamic guidance from supervisor if enabled
    guidance = _ask_supervisor_for_guidance(workflow, count, max_count, transcript_path)
    if guidance:
        return guidance

    # Fall back to static template from external file
    try:
        template = _load_prompt_template(workflow)
        template += '''
- If the goal is complete, ask the host session to use the command below to mark the workflow as done:
    jq '.state = "done"' {{#fname#}} > {{#fname#}}.tmp && mv {{#fname#}}.tmp {{#fname#}}
-  No matter creating a Issue or PR, always as the host session to use `--body-file` to provide detailed descriptions,
   as embedded `--` in `--body` may confuse the CLI parser.
'''
    except FileNotFoundError:
        return ''

    # Build plan context for issue-to-impl workflow
    plan_context = ''
    if workflow == ISSUE_TO_IMPL and plan_path:
        plan_context = f'''- Plan file: {plan_path}'''
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
