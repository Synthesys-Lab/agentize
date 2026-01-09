#!/usr/bin/env python3
"""PreToolUse hook - thin wrapper delegating to agentize.permission module.

This hook imports and invokes agentize.permission.determine() for all permission
decisions. Rules are defined in python/agentize/permission/rules.py.

Falls back to 'ask' on any import/execution errors.
"""

import json
import sys
from pathlib import Path


def main():
    try:
        repo_root = Path(__file__).resolve().parents[2]
        sys.path.insert(0, str(repo_root / "python"))
        from agentize.permission import determine
        result = determine(sys.stdin.read())
    except Exception:
        result = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask"}}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
