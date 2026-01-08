"""Input parsing utilities for hook data.

This module provides functions to parse hook input JSON and extract
tool-specific target strings for permission rule matching.
"""

import json
from typing import Dict, Any


def parse_hook_input(stdin_data: str) -> Dict[str, Any]:
    """Parse JSON hook input from stdin.

    Args:
        stdin_data: Raw JSON string from Claude Code hook

    Returns:
        Parsed dict with tool_name, session_id, tool_input, etc.
    """
    return json.loads(stdin_data)


def extract_target(tool: str, tool_input: Dict[str, Any]) -> str:
    """Extract relevant target string from tool_input based on tool type.

    Args:
        tool: Tool name (e.g., 'Bash', 'Read', 'Skill')
        tool_input: Tool-specific input dict

    Returns:
        Target string for permission rule matching
    """
    if tool in ['Read', 'Write', 'Edit', 'NotebookEdit']:
        return tool_input.get('file_path', '')
    elif tool == 'Bash':
        return tool_input.get('command', '')
    elif tool == 'Grep':
        pattern = tool_input.get('pattern', '')
        path = tool_input.get('path', '')
        return f'pattern={pattern}' + (f' path={path}' if path else '')
    elif tool == 'Glob':
        pattern = tool_input.get('pattern', '')
        path = tool_input.get('path', '')
        return f'pattern={pattern}' + (f' path={path}' if path else '')
    elif tool == 'Task':
        subagent = tool_input.get('subagent_type', '')
        desc = tool_input.get('description', '')
        return f'subagent={subagent} desc={desc}'
    elif tool == 'Skill':
        skill = tool_input.get('skill', '')
        args = tool_input.get('args', '')
        return skill + (f' {args}' if args else '')
    elif tool == 'WebFetch':
        return tool_input.get('url', '')
    elif tool == 'WebSearch':
        query = tool_input.get('query', '')
        return f'query={query}'
    elif tool == 'LSP':
        op = tool_input.get('operation', '')
        file_path = tool_input.get('filePath', '')
        line = tool_input.get('line', '')
        return f'op={op} file={file_path}:{line}'
    elif tool == 'AskUserQuestion':
        questions = tool_input.get('questions', [])
        if questions:
            headers = [q.get('header', '') for q in questions]
            return f'questions={",".join(headers)}'
        return ''
    elif tool == 'TodoWrite':
        todos = tool_input.get('todos', [])
        return f'todos={len(todos)}'
    else:
        # For other tools, try to get a representative field
        return str(tool_input)[:100]
