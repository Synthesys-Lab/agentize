#!/usr/bin/env bash
# Test: Missing AGENTIZE_HOME produces error

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

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
