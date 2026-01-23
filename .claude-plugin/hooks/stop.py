#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path

# Add .claude-plugin to path for lib imports
_plugin_dir = Path(__file__).resolve().parent.parent
if str(_plugin_dir) not in sys.path:
    sys.path.insert(0, str(_plugin_dir))

from lib.logger import logger
from lib.session_utils import session_dir
from lib.workflow import get_continuation_prompt, ISSUE_TO_IMPL


def main():

    handsoff = os.getenv('HANDSOFF_MODE', '1')
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
    sess_dir = session_dir()
    fname = os.path.join(sess_dir, f'{session_id}.json')
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

        # Read cached plan for issue-to-impl workflow
        plan_path = None
        plan_excerpt = None
        if workflow == ISSUE_TO_IMPL:
            issue_no = state.get('issue_no')
            if issue_no:
                agentize_home = os.getenv('AGENTIZE_HOME', '.')
                plan_path = os.path.join(agentize_home, '.tmp', f'plan-of-issue-{issue_no}.md')
                if os.path.isfile(plan_path):
                    try:
                        with open(plan_path, 'r') as pf:
                            plan_content = pf.read()
                        # Truncate to reasonable size (first 500 chars)
                        if len(plan_content) > 500:
                            plan_excerpt = plan_content[:500] + '...'
                        else:
                            plan_excerpt = plan_content
                        logger(session_id, f"Read cached plan from {plan_path} ({len(plan_content)} chars)")
                    except Exception as e:
                        logger(session_id, f"Failed to read cached plan: {e}")
                        plan_path = None  # Reset if read fails
                else:
                    logger(session_id, f"No cached plan found at {plan_path}")
                    plan_path = None  # No plan file exists

        prompt = get_continuation_prompt(
            workflow,
            session_id,
            fname,
            continuation_count + 1,
            max_continuations,
            pr_no=pr_no,
            plan_path=plan_path,
            plan_excerpt=plan_excerpt
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
