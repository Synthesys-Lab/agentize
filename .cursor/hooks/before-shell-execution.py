#!/usr/bin/env python3
"""beforeShellExecution hook - delegates to agentize.permission module.

This hook intercepts shell commands and uses the permission system to determine
if they should be allowed, denied, or require user approval.

Falls back to 'ask' on any import/execution errors.
"""

import json
import os
import sys
from pathlib import Path


def main():
    try:
        # Read hook input from stdin
        hook_input = json.load(sys.stdin)
        
        # Extract command and cwd from beforeShellExecution input
        command = hook_input.get("command", "")
        cwd = hook_input.get("cwd", "")
        conversation_id = hook_input.get("conversation_id", "")
        generation_id = hook_input.get("generation_id", "")
        
        # Use conversation_id as session_id, fallback to generation_id
        session_id = conversation_id or generation_id or "unknown"
        
        # Setup Python path to import agentize.permission
        # Dual-mode: plugin mode uses CLAUDE_PLUGIN_ROOT, project-local uses relative path
        plugin_dir = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if plugin_dir:
            sys.path.insert(0, os.path.join(plugin_dir, "python"))
        else:
            # Project-local mode: hooks/ is at .cursor/hooks/, 2 levels below repo root
            repo_root = Path(__file__).resolve().parents[2]
            sys.path.insert(0, str(repo_root / "python"))
        
        # Import permission determination function
        from agentize.permission import determine
        
        # Format input as PreToolUse-style JSON for the permission system
        # The permission system expects: tool_name, session_id, tool_input
        pre_tool_use_input = {
            "tool_name": "Bash",
            "session_id": session_id,
            "tool_input": {
                "command": command
            },
            "transcript_path": "",  # May not be available for shell execution
            "conversation_id": conversation_id,
            "generation_id": generation_id,
        }
        
        # Call the permission determination system
        permission_result = determine(json.dumps(pre_tool_use_input))
        
        # Extract permission decision from result
        permission_decision = permission_result.get(
            "hookSpecificOutput", {}
        ).get("permissionDecision", "ask")
        
        # Build response in beforeShellExecution format
        result = {
            "continue": True,
            "permission": permission_decision
        }
        
        # Add optional messages based on decision
        if permission_decision == "deny":
            result["user_message"] = f"Shell command blocked: {command[:100]}"
            result["agent_message"] = f"The shell command '{command[:200]}' has been blocked by the permission system. Please use a safer alternative or request approval."
        elif permission_decision == "ask":
            result["user_message"] = f"Shell command requires approval: {command[:100]}"
            result["agent_message"] = f"The shell command '{command[:200]}' requires manual approval. Please review and approve if you want to proceed."
        # For "allow", no additional messages needed
        
        print(json.dumps(result))
        
    except Exception as e:
        # On any error, default to asking for permission
        error_msg = str(e)[:200] if str(e) else "unknown error"
        result = {
            "continue": True,
            "permission": "ask",
            "user_message": f"Error checking permission: {error_msg}",
            "agent_message": f"An error occurred while checking permissions for the shell command. Manual approval required."
        }
        print(json.dumps(result))
        sys.exit(0)


if __name__ == "__main__":
    main()
