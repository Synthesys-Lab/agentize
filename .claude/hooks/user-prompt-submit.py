#!/usr/bin/env python3

import os
import sys
import json
import shutil

from logger import logger

def main():

    handsoff = os.getenv('HANDSOFF_MODE', '0')

    # Do nothing if handsoff mode is disabled
    if handsoff.lower() in ['0', 'false', 'off', 'disable']:
        logger('SYSTEM', f'Handsoff mode disabled, exiting hook, {handsoff}')
        sys.exit(0)

    hook_input = json.load(sys.stdin)

    error = {'decision': 'block'}
    prompt = hook_input.get("prompt", "")
    if not prompt:
        error['reason'] = 'No prompt provided.'

    session_id = hook_input.get("session_id", "")
    if not session_id:
        error['reason'] = 'No session_id provided.'

    if error.get('reason', None):
        print(json.dumps(error))
        logger('SYSTEM', f"Error in hook input: {error['reason']}")
        sys.exit(1)

    state = {}

    # Every time, once it comes to these two workflows,
    # reset the state to initial, and the continuation count to 0.

    if prompt.startswith('/ultra-planner'):
        state['workflow'] = 'ultra-planner'
        state['state'] = 'initial'

    if prompt.startswith('/issue-to-impl'):
        state['workflow'] = 'issue-to-impl'
        state['state'] = 'initial'

    if state:
        state['continuation_count'] = 0
        # Create the folder if it doesn't exist
        os.makedirs('.tmp', exist_ok=True)
        os.makedirs('.tmp/hooked-sessions', exist_ok=True)

        with open(f'.tmp/hooked-sessions/{session_id}.json', 'w') as f:
            logger(session_id, f"Writing state: {state}")
            json.dump(state, f)
    else:
        logger(session_id, "No workflow matched, doing nothing.")

if __name__ == "__main__":
    main()
