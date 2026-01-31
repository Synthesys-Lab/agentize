#!/usr/bin/env bash
# Test: wt rebase subcommand has complete zsh completion support

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_wt"

test_info "wt rebase has complete zsh completion support"

# Test 1: Verify 'rebase' appears in static fallback command list
if ! grep -E "^\s+'rebase:" "$COMPLETION_FILE" >/dev/null; then
  test_fail "'rebase' not found in static fallback command list"
fi

# Test 2: Verify _wt_rebase() helper function exists
if ! grep -q "^_wt_rebase()" "$COMPLETION_FILE"; then
  test_fail "_wt_rebase() helper function not found"
fi

# Test 3: Verify args case statement includes 'rebase' handler
if ! grep -q "rebase)" "$COMPLETION_FILE"; then
  test_fail "'rebase' case handler not found in args switch"
fi

# Test 4: Verify dynamic description mapping includes 'rebase'
if ! grep -q 'rebase) commands_with_desc' "$COMPLETION_FILE"; then
  test_fail "'rebase' not found in dynamic description mapping"
fi

test_pass "wt rebase has complete zsh completion support"
