#!/usr/bin/env python3

import os
import sys
import json

from logger import logger

# Add python directory to path for agentize imports
_python_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'python')
if _python_dir not in sys.path:
    sys.path.insert(0, _python_dir)

from agentize.workflow import (
    detect_workflow,
    extract_issue_no,
    extract_pr_no,
    SYNC_MASTER,
)


def _session_dir():
    """Get session directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    return os.path.join(base, '.tmp', 'hooked-sessions')


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
        session_dir = _session_dir()
        os.makedirs(session_dir, exist_ok=True)

        session_file = os.path.join(session_dir, f'{session_id}.json')
        with open(session_file, 'w') as f:
            logger(session_id, f"Writing state: {state}")
            json.dump(state, f)

        # Create issue index file if issue_no is present
        if issue_no is not None:
            by_issue_dir = os.path.join(session_dir, 'by-issue')
            os.makedirs(by_issue_dir, exist_ok=True)
            issue_index_file = os.path.join(by_issue_dir, f'{issue_no}.json')
            with open(issue_index_file, 'w') as f:
                index_data = {'session_id': session_id, 'workflow': state['workflow']}
                logger(session_id, f"Writing issue index: {index_data}")
                json.dump(index_data, f)
    else:
        logger(session_id, "No workflow matched, doing nothing.")

if __name__ == "__main__":
    main()
