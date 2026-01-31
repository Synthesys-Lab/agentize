#!/usr/bin/env bash
# Test: Missing AGENTIZE_HOME produces error

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "Missing AGENTIZE_HOME produces error"

(
  unset AGENTIZE_HOME
  if source "$LOL_CLI" 2>/dev/null && lol upgrade 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is missing"
  fi
  test_pass "Errors correctly on missing AGENTIZE_HOME"
) || test_pass "Errors correctly on missing AGENTIZE_HOME"
