#!/usr/bin/env python3
"""stop hook - Auto-continue workflow with workflow-specific prompts.

This hook intercepts the stop event and checks if there's an active handsoff
workflow session. If so, it blocks the stop and injects a continuation prompt
to keep the workflow running until completion.

Falls back to allowing stop if handsoff mode is disabled or no session state exists.
"""

import os
import sys
import json

# Add hooks directory to Python path so we can import logger
hooks_dir = os.path.dirname(os.path.abspath(__file__))
if hooks_dir not in sys.path:
    sys.path.insert(0, hooks_dir)

# Add python directory to path for agentize imports
_python_dir = os.path.join(hooks_dir, '..', '..', 'python')
if _python_dir not in sys.path:
    sys.path.insert(0, _python_dir)

from logger import logger
from agentize.workflow import get_continuation_prompt


def _session_dir():
    """Get session directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    os.makedirs(base, exist_ok=True)
    os.makedirs(os.path.join(base, '.tmp', 'hooked-sessions'), exist_ok=True)
    return os.path.join(base, '.tmp', 'hooked-sessions')


def main():
    # Read hook input from stdin first
    hook_input = json.load(sys.stdin)

    handsoff = os.getenv('HANDSOFF_MODE', '0')
    # Do nothing if handsoff mode is disabled
    if handsoff.lower() in ['0', 'false', 'off', 'disable']:
        logger('SYSTEM', f'Handsoff mode disabled, exiting hook, {handsoff}')
        # Allow stop to proceed when handsoff mode is disabled
        print(json.dumps({"decision": "allow"}))
        sys.exit(0)

    # Extract session identifier from hook input
    # Cursor may provide conversation_id, generation_id, or session_id
    session_id = (
        hook_input.get("session_id", "") or
        hook_input.get("conversation_id", "") or
        hook_input.get("generation_id", "") or
        "unknown"
    )

    # Check for transcript_path and insufficient credit error (if available)
    transcript_path = hook_input.get("transcript_path", "")
    if transcript_path and os.path.exists(transcript_path):
        try:
            with open(transcript_path, 'r') as f:
                lines = f.readlines()
                if lines:
                    last_line = lines[-1]
                    last_entry = json.loads(last_line)
                    if last_entry.get('isApiErrorMessage') and 'Insufficient credit' in str(
                        last_entry.get('message', {}).get('content', [])
                    ):
                        logger(session_id, "Insufficient credits detected, stopping auto-continuation")
                        print(json.dumps({"decision": "allow"}))
                        sys.exit(0)
        except (json.JSONDecodeError, Exception) as e:
            # If we can't parse the last entry, continue with normal flow
            logger(session_id, f"Could not parse last transcript entry: {e}")

    # Check the file existence using AGENTIZE_HOME fallback
    session_dir = _session_dir()
    fname = os.path.join(session_dir, f'{session_id}.json')
    if os.path.exists(fname):
        logger(session_id, f"Found existing state file: {fname}")
        with open(fname, 'r') as f:
            state = json.load(f)

        # Check for done state first (takes priority over continuation_count)
        workflow_state = state.get('state', 'initial')
        if workflow_state == 'done':
            logger(session_id, "State is 'done', stopping continuation")
            print(json.dumps({"decision": "allow"}))
            sys.exit(0)

        max_continuations = os.getenv('HANDSOFF_MAX_CONTINUATIONS', '10')
        max_continuations = int(max_continuations)

        continuation_count = state.get('continuation_count', 0)
        if continuation_count >= max_continuations:
            logger(session_id, f"Max continuations ({max_continuations}) reached, stopping continuation")
            print(json.dumps({"decision": "allow"}))
            sys.exit(0)
        else:
            state['continuation_count'] = continuation_count + 1
            workflow = state.get('workflow', '')

        # Get continuation prompt from centralized workflow module
        pr_no = state.get('pr_no', 'unknown')
        prompt = get_continuation_prompt(
            workflow,
            session_id,
            fname,
            continuation_count + 1,
            max_continuations,
            pr_no=pr_no
        )

        if prompt:
            with open(fname, 'w') as f:
                logger(session_id, f"Updating state for continuation: {state}")
                json.dump(state, f)
            # NOTE: `dumps` is REQUIRED or Cursor will just ignore your output!
            print(json.dumps({
                'decision': 'block',
                'reason': prompt
            }))
        else:
            # No workflow matched, do nothing
            logger(session_id, f"No workflow matched, \"{workflow}\", doing nothing.")
            print(json.dumps({"decision": "allow"}))
            sys.exit(0)
    else:
        # We can do nothing if no state file exists
        logger(session_id, f"No existing state file found: {fname}, doing nothing.")
        print(json.dumps({"decision": "allow"}))
        sys.exit(0)


if __name__ == "__main__":
    main()
