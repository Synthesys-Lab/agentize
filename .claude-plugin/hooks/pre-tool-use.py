#!/usr/bin/env python3
"""PreToolUse hook - thin wrapper delegating to lib.permission module.

This hook imports and invokes lib.permission.determine() for all permission
decisions. Rules are defined in .claude-plugin/lib/permission/rules.py.

Falls back to 'ask' on any import/execution errors.
"""

import json
import os
import sys
from pathlib import Path


def main():
    try:
        # Add .claude-plugin to path for lib imports
        plugin_dir = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if plugin_dir:
            sys.path.insert(0, plugin_dir)
        else:
            # Project-local mode: hooks/ is at .claude-plugin/hooks/
            plugin_dir = Path(__file__).resolve().parent.parent
            sys.path.insert(0, str(plugin_dir))
        from lib.permission import determine
        result = determine(sys.stdin.read())
    except Exception as e:
        os.makedirs('.tmp', exist_ok=True)
        with open('.tmp/pre_tool_use_hook_error.log', 'w') as f:
            f.write("Error in PreToolUse hook:\n")
            import traceback
            traceback.print_exc(file=f)
            f.write(str(e))
        result = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask"}}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
