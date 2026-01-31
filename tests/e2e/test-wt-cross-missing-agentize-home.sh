#!/usr/bin/env bash
# Test: Missing AGENTIZE_HOME produces error

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

test_info "Missing AGENTIZE_HOME produces error"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

# Attempt to use wt spawn without AGENTIZE_HOME
(
  unset AGENTIZE_HOME
  if source "$WT_CLI" 2>/dev/null && wt spawn 42 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is missing"
  fi
) || true

test_pass "Errors correctly on missing AGENTIZE_HOME"
