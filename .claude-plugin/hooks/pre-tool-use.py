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

# Add .claude-plugin to path for lib imports
_plugin_dir = Path(__file__).resolve().parent.parent
if str(_plugin_dir) not in sys.path:
    sys.path.insert(0, str(_plugin_dir))

from lib.logger import logger

def main():
    logger('SYSTEM', f'PreToolUse hook started')
    try:
        from lib.permission import determine
        result = determine(sys.stdin.read(), caller='PreToolUse')
    except Exception as e:
        import traceback
        logger('SYSTEM', f'PreToolUse hook error: {e}')
        logger('SYSTEM', f'PreToolUse hook error traceback: {traceback.format_exc()}')
        result = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask"}}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
