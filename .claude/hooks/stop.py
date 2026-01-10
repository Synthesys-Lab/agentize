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


    # Check the file existence
    fname = f'.tmp/hooked-sessions/{session_id}.json'
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
        prompt = ''
        if workflow == 'ultra-planner':
            prompt = f'''
This is an auto-continuation prompt for handsoff mode, it is currently {continuation_count}/{max_continuations} continuations.
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
5. When creating issues or PRs, use `--body-file` instead of `--body`, as body content with "--something" will be misinterpreted as flags.'''.strip()
        elif workflow == 'issue-to-impl':
            prompt = f'''
This is an auto-continuation prompt for handsoff mode, it is currently {continuation_count}/{max_continuations} continuations.
The ultimate goal of this workflow is to deliver a PR on GitHub that implements the corresponding issue. Did you have this delivered?
1. If you have completed a milestone but still have more to do, please continue on the next milestone!
1.5. If you are working on documentation updates (Step 5):
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
7. When creating issues or PRs, use `--body-file` instead of `--body`, as body content with "--something" will be misinterpreted as flags.'''

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
            logger(session_id, "No workflow matched, \"{workflow}\", doing nothing.")
            sys.exit(0)
    else:
        # We can do nothing if no state file exists
        logger(session_id, f"No existing state file found: {fname}, doing nothing.")
        sys.exit(0)


if __name__ == "__main__":
    main()
