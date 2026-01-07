#!/usr/bin/env python3
import os
import sys
import json
from logger import logger

def main():

    handsoff = os.getenv('HANDSOFF_MODE', '0')
    # Do nothing if handsoff mode is disabled
    if handsoff.lower() in ['0', 'false', 'off', 'disable']:
        sys.exit(0)

    hook_input = json.load(sys.stdin)
    session_id = hook_input.get("session_id", "")

    # Check the file existence
    fname = f'.tmp/hooked-sessions/{session_id}.json'
    if os.path.exists(fname):
        logger(session_id, "Found existing state file: {fname}")
        with open(fname, 'r') as f:
            state = json.load(f)
            max_continuations = os.getenv('HANDSOFF_MAX_CONTINUATIONS', '10')
            max_continuations = int(max_continuations)

            continuation_count = state.get('continuation_count', 0)
            if continuation_count >= max_continuations:
                sys.exit(0)  # Do nothing if max continuations reached
            else:
                state['continuation_count'] = continuation_count + 1
                workflow = state.get('workflow', '')
        prompt = ''
        if workflow == 'ultra-planner':
            prompt = f'''
This is an auto-continuation prompt for handsoff mode, it is currently {continuation_count}/{max_continuations} continuations. 
The ultimate goal of this workflow is to create a comprehensive plan and post it on GitHub Issue. Did you have this delivered?
1. If not, please continue on this! Try to be as hands-off as possible, avoid asking user design decision questions, and choose the one you most recommended.
2. If you have already delivered the plan, please tell me "Yes! I am done!"
  - Set `{fname}` continuation count to {max_continuations} to stop further continuations.
3. If you are stuck, and does not know what to do next. Please post a comment on GitHub Issue asking for help.
  - First, set `{fname}` continuation count to {max_continuations} to stop further continuations.
  - Then, post a comment on GitHub Issue asking for help. This comment shall include:
    - What you have done so far
    - What is blocking you from moving forward
    - What kind of help you need from human collaborators
    - The session ID: {session_id} so that human can `claude -r {session_id}` for a human intervention.
            '''.strip()
        elif workflow == 'issue-to-impl':
            prompt = f'''
This is an auto-continuation prompt for handsoff mode, it is currently {continuation_count}/{max_continuations} continuations. 
The ultimate goal of this workflow is to deliver a PR on GitHut that implements the corresponding issue. Did you have this delivered?
1. If you are done with a milestone, but still having next ones. Please continue on the latest milestone!
2. If you have every coding task done, go to /code-review step.
3. If code review is concerning, fix the code review comments and repeat /code-review step.
4. If code review is good, open the PR!
5. If you are gonna open the PR, look at `CLAUDE.md` to run the full test suite locally before opening the PR.
   - If it is failing fix the issues before opening the PR.
   - If it is passing, proceed to open the PR.
6. After preparing the PR description, do not ask "Should I open the PR?" Just open it right away.
7. If the PR is successfully created, please tell me "Yes! I am done!"
  - Set `{fname}` continuation count to {max_continuations} to stop further continuations.
8. If you are stuck, and does not know what to do next. Please post a comment on GitHub Issue asking for help.
  - First, set `{fname}` continuation count to {max_continuations} to stop further continuations.
  - This comment shall include:
    - What you have done so far
    - What is blocking you from moving forward
    - What kind of help you need from human collaborators
    - The session ID: {session_id} so that human can `claude -r {session_id}` for a human intervention.
            '''

        if prompt:
            with open(fname, 'w') as f:
                logger(session_id, f"Updating state for continuation: {state}")
                json.dump(state, f)
            print(json.dumps({
                'decision': 'block',
                'reason': prompt
            }))
        else:
            # No workflow matched, do nothing
            logger(session_id, "No workflow matched, \"{workflow}\", doing nothing.")
            sys.exit(0)
    else:
        # We can do nothing if no state file exists
        logger(session_id, f"No existing state file found: {fname}, doing nothing.")
        sys.exit(0)


if __name__ == "__main__":
    main()
