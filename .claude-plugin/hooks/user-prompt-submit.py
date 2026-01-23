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
from lib.session_utils import session_dir, is_handsoff_enabled, write_issue_index
from lib.workflow import (
    detect_workflow,
    extract_issue_no,
    extract_pr_no,
    SYNC_MASTER,
)


def main():
    # Do nothing if handsoff mode is disabled
    if not is_handsoff_enabled():
        logger('SYSTEM', f'Handsoff mode disabled, exiting hook')
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

    # Detect workflow using centralized workflow module
    workflow = detect_workflow(prompt)
    if workflow:
        state['workflow'] = workflow
        state['state'] = 'initial'

        # Extract PR number for sync-master workflow
        if workflow == SYNC_MASTER:
            pr_no = extract_pr_no(prompt)
            if pr_no is not None:
                state['pr_no'] = pr_no

    if state:
        # Extract optional issue number from command arguments
        issue_no = extract_issue_no(prompt)
        if issue_no is not None:
            state['issue_no'] = issue_no

        state['continuation_count'] = 0

        # Create session directory using AGENTIZE_HOME fallback
        sess_dir = session_dir(makedirs=True)

        session_file = os.path.join(sess_dir, f'{session_id}.json')
        with open(session_file, 'w') as f:
            logger(session_id, f"Writing state: {state}")
            json.dump(state, f)

        # Create issue index file if issue_no is present
        if issue_no is not None:
            write_issue_index(session_id, issue_no, state['workflow'], sess_dir=sess_dir)
            logger(session_id, f"Writing issue index: session_id={session_id}, issue_no={issue_no}")
    else:
        logger(session_id, "No workflow matched, doing nothing.")

if __name__ == "__main__":
    main()
