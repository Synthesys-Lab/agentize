#!/usr/bin/env python3

import sys
import json
import os

# Currently, this hook logs tools used in HANDSOFF_MODE to a file for each session.

hook_input = json.load(sys.stdin)

if os.getenv('HANDSOFF_MODE', '0').lower() not in ['1', 'true', 'on', 'enable']:
    sys.exit(0)

tool = hook_input['tool_name']
session = hook_input['session_id']

if  os.getenv('HANDSOFF_DEBUG', '0').lower() not in ['1', 'true', 'on', 'enable']:
    os.makedirs('.tmp', exist_ok=True)
    os.makedirs('.tmp/hooked-sessions', exist_ok=True)
    with open(f'.tmp/hooked-sessions/{session}.tool-used.txt', 'a') as f:
        f.write(f'{tool}\n')