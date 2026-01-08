#!/usr/bin/env python3
"""PreToolUse hook - Thin shell that delegates to agentize.permission.determine()."""

import sys
import os
import json

# Add python package to path (relative to this file's location)
_script_dir = os.path.dirname(os.path.abspath(__file__))
_python_dir = os.path.join(_script_dir, '..', '..', 'python')
if _python_dir not in sys.path:
    sys.path.insert(0, _python_dir)

try:
    from agentize.permission import determine
    result = determine(sys.stdin.read())
    print(json.dumps(result))
except Exception as e:
    # Fallback: if import fails, return 'ask' to prompt user
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask"
        }
    }
    print(json.dumps(output))
    # Log error if debug enabled
    if os.getenv('HANDSOFF_DEBUG', '0').lower() in ['1', 'true', 'on', 'enable']:
        os.makedirs('.tmp', exist_ok=True)
        with open('.tmp/hook-debug.log', 'a') as f:
            f.write(f"[pre-tool-use.py] Import error: {str(e)}\n")
