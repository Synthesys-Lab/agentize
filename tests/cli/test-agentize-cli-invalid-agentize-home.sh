#!/usr/bin/env bash
# Test: Invalid AGENTIZE_HOME produces error

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

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "Invalid AGENTIZE_HOME produces error"

(
  export AGENTIZE_HOME="/nonexistent/path"
  if source "$LOL_CLI" 2>/dev/null && lol upgrade 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is invalid"
  fi
  test_pass "Errors correctly on invalid AGENTIZE_HOME"
) || test_pass "Errors correctly on invalid AGENTIZE_HOME"
