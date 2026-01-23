#!/usr/bin/env python3
"""PostToolUse hook to capture issue numbers from gh issue create during Ultra Planner workflow.

This hook intercepts successful `gh issue create` commands and extracts the issue number
from the output URL. When running in an Ultra Planner workflow context, it updates the
session state file with the captured issue number for use in subsequent workflow steps.

Input (via stdin):
    JSON object with tool_name, tool_input, tool_response

Output:
    JSON with additionalContext if issue captured, otherwise exits silently

See: https://docs.anthropic.com/en/docs/claude-code/hooks
"""

import os
import sys
import json
import re
from pathlib import Path

# Add .claude-plugin to path for lib imports
_plugin_dir = Path(__file__).resolve().parent.parent
if str(_plugin_dir) not in sys.path:
    sys.path.insert(0, str(_plugin_dir))

from lib.logger import logger
from lib.session_utils import session_dir, write_issue_index
from lib.workflow import ULTRA_PLANNER


def _extract_issue_number_from_output(output: str) -> int | None:
    """Extract issue number from gh issue create output.

    The output typically contains a URL like:
    https://github.com/Synthesys-Lab/agentize/issues/544

    Args:
        output: Raw output from gh issue create command

    Returns:
        Issue number as int, or None if not found
    """
    # Look for GitHub issue URL pattern in the output
    url_pattern = r'https://github\.com/[^/]+/[^/]+/issues/(\d+)'
    match = re.search(url_pattern, output)
    if match:
        return int(match.group(1))
    return None


def main():
    hook_input = json.load(sys.stdin)

    session_id = hook_input.get("session_id", "")
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    tool_response = hook_input.get("tool_response", {})

    # Only process Bash tool
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")

    # Only process gh issue create commands
    if "gh issue create" not in command:
        sys.exit(0)

    # Extract issue number from tool response
    # The response structure depends on how Claude Code captures Bash output
    output = ""
    if isinstance(tool_response, dict):
        output = tool_response.get("stdout", "") or tool_response.get("output", "") or str(tool_response)
    elif isinstance(tool_response, str):
        output = tool_response

    issue_no = _extract_issue_number_from_output(output)

    if issue_no is None:
        logger(session_id, f"Could not extract issue number from gh issue create output: {output[:200]}")
        sys.exit(0)

    logger(session_id, f"Captured issue number {issue_no} from gh issue create")

    # Check if we're in an Ultra Planner workflow
    sess_dir = session_dir()
    session_file = os.path.join(sess_dir, f'{session_id}.json')

    if not os.path.exists(session_file):
        logger(session_id, f"No session state file found at {session_file}")
        sys.exit(0)

    with open(session_file, 'r') as f:
        state = json.load(f)

    workflow = state.get('workflow', '')

    # Only update for Ultra Planner workflow
    if workflow != ULTRA_PLANNER:
        logger(session_id, f"Not in Ultra Planner workflow (current: {workflow}), skipping issue capture")
        sys.exit(0)

    # Check if issue_no is already set (don't overwrite)
    if state.get('issue_no') is not None:
        logger(session_id, f"Issue number already set to {state['issue_no']}, not overwriting")
        sys.exit(0)

    # Update session state with captured issue number
    state['issue_no'] = issue_no

    with open(session_file, 'w') as f:
        logger(session_id, f"Updating session state with issue_no={issue_no}")
        json.dump(state, f)

    # Create issue index file for reverse lookup
    write_issue_index(session_id, issue_no, workflow, sess_dir=sess_dir)
    logger(session_id, f"Writing issue index: session_id={session_id}, issue_no={issue_no}")


if __name__ == "__main__":
    main()
