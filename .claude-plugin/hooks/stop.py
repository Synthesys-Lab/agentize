#!/usr/bin/env python3
import os
import sys
import json
from logger import logger

# Add python directory to path for agentize imports
_python_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'python')
if _python_dir not in sys.path:
    sys.path.insert(0, _python_dir)

from agentize.workflow import get_continuation_prompt


def _session_dir():
    """Get session directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    return os.path.join(base, '.tmp', 'hooked-sessions')


def main():

    handsoff = os.getenv('HANDSOFF_MODE', '0')
    # Do nothing if handsoff mode is disabled
    if handsoff.lower() in ['0', 'false', 'off', 'disable']:
        sys.exit(0)

    hook_input = json.load(sys.stdin)
    session_id = hook_input.get("session_id", "")
    transcript_path = hook_input.get("transcript_path", "")
    transript = open(transcript_path, 'r').readlines()[-1]

    # Check for Insufficient Credit error
    try:
        last_entry = json.loads(transript)
        if last_entry.get('isApiErrorMessage') and 'Insufficient credit' in str(last_entry.get('message', {}).get('content', [])):
            logger(session_id, "Insufficient credits detected, stopping auto-continuation")
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
                sys.exit(0)

            max_continuations = os.getenv('HANDSOFF_MAX_CONTINUATIONS', '10')
            max_continuations = int(max_continuations)

            continuation_count = state.get('continuation_count', 0)
            if continuation_count >= max_continuations:
                sys.exit(0)  # Do nothing if max continuations reached
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
            # NOTE: `dumps` is REQUIRED ow Claude Code will just ignore your output!
            print(json.dumps({
                'decision': 'block',
                'reason': prompt
            }))
        else:
            # No workflow matched, do nothing
            logger(session_id, f"No workflow matched, \"{workflow}\", doing nothing.")
            sys.exit(0)
    else:
        # We can do nothing if no state file exists
        logger(session_id, f"No existing state file found: {fname}, doing nothing.")
        sys.exit(0)


if __name__ == "__main__":
    main()
