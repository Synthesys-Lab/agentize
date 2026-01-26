#!/usr/bin/env bash
# Test: lol serve subcommand has complete zsh completion support (no CLI flags)

source "$(dirname "$0")/../common.sh"

COMPLETION_FILE="$PROJECT_ROOT/src/completion/_lol"

test_info "lol serve has complete zsh completion support (no CLI flags)"

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

# Test 5: Verify _lol_serve() does NOT have old TG flags (YAML-only now)
if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-token"; then
  test_fail "_lol_serve() should NOT have --tg-token flag (moved to YAML-only)"
fi

if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--tg-chat-id"; then
  test_fail "_lol_serve() should NOT have --tg-chat-id flag (moved to YAML-only)"
fi

# Test 6: Verify _lol_serve() does NOT have --period or --num-workers (YAML-only now)
if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--period"; then
  test_fail "_lol_serve() should NOT have --period flag (moved to YAML-only)"
fi

if grep -A20 "^_lol_serve()" "$COMPLETION_FILE" | grep -q -- "--num-workers"; then
  test_fail "_lol_serve() should NOT have --num-workers flag (moved to YAML-only)"
fi

# Test 7: Verify _lol_serve() provides YAML-only documentation
if ! grep -A10 "^_lol_serve()" "$COMPLETION_FILE" | grep -q "\.agentize\.local\.yaml\|YAML"; then
  test_fail "_lol_serve() should mention YAML configuration"
fi

test_pass "lol serve has complete zsh completion support (no CLI flags)"
