"""String normalization utilities for bash commands.

This module provides functions to strip environment variables and shell prefixes
from bash commands for consistent permission rule matching.
"""

import re


def strip_env_vars(command: str) -> str:
    """Strip leading ENV=value pairs from bash commands."""
    # Match one or more ENV=value patterns at the start
    env_pattern = re.compile(r'^(\w+=\S+\s+)+')
    return env_pattern.sub('', command)


def strip_shell_prefixes(command: str) -> str:
    """Strip leading shell option prefixes from bash commands.

    Common prefixes like 'set -x && ' or 'set -e && ' are debugging/safety
    options that don't change command semantics for permission purposes.
    """
    # Match patterns like: set -x && , set -e && , set -o pipefail &&
    prefix_pattern = re.compile(r'^(set\s+-[exo]\s+[a-z]*\s*&&\s*)+', re.IGNORECASE)
    return prefix_pattern.sub('', command)


def normalize_bash_command(command: str) -> str:
    """Normalize bash command by stripping env vars and shell prefixes."""
    command = strip_env_vars(command)
    command = strip_shell_prefixes(command)
    return command
