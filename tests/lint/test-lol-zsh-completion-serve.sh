#!/usr/bin/env bash
# Test: lol serve subcommand has complete zsh completion support

source "$(dirname "$0")/../common.sh"

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_lol"

test_info "lol serve has complete zsh completion support"

# Test 1: Verify 'serve' appears in static fallback command list
if ! grep -E "^\s+'serve:" "$COMPLETION_FILE" >/dev/null; then
  test_fail "'serve' not found in static fallback command list"
fi

# Test 2: Verify _lol_serve() helper function exists
if ! grep -q "^_lol_serve()" "$COMPLETION_FILE"; then
  test_fail "_lol_serve() helper function not found"
fi

# Test 3: Verify args case statement includes 'serve' handler
if ! grep -q "serve)" "$COMPLETION_FILE"; then
  test_fail "'serve' case handler not found in args switch"
fi

# Test 4: Verify dynamic description mapping includes 'serve'
if ! grep -q 'serve) commands_with_desc' "$COMPLETION_FILE"; then
  test_fail "'serve' not found in dynamic description mapping"
fi

# Test 5: Verify _lol_serve() handles the expected flags
if ! grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-token"; then
  test_fail "_lol_serve() missing --tg-token flag"
fi

if ! grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-chat-id"; then
  test_fail "_lol_serve() missing --tg-chat-id flag"
fi

test_pass "lol serve has complete zsh completion support"
