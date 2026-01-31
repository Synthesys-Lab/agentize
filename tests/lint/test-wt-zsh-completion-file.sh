#!/usr/bin/env bash
# Test: zsh completion file exists and has correct structure

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_wt"

test_info "zsh completion file exists and has correct structure"

# Verify file exists
if [ ! -f "$COMPLETION_FILE" ]; then
  test_fail "Completion file not found: $COMPLETION_FILE"
fi

# Verify file contains #compdef wt directive
if ! grep -q "^#compdef wt" "$COMPLETION_FILE"; then
  test_fail "Completion file missing '#compdef wt' directive"
fi

# Verify file is not empty (should have at least 10 lines)
line_count=$(wc -l < "$COMPLETION_FILE")
if [ "$line_count" -lt 10 ]; then
  test_fail "Completion file seems too short ($line_count lines)"
fi

test_pass "zsh completion file exists with correct structure"
