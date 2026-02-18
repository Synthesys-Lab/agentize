#!/usr/bin/env bash
# Test: Tab styling CSS properties for equal-width tabs with overflow protection

source "$(dirname "$0")/../common.sh"

test_info "Testing tab styling CSS properties"

PROVIDER_FILE="vscode/src/view/unifiedViewProvider.ts"

# Check that the required CSS properties are present in .unified-tab
if ! grep -q "flex: 1;" "$PROVIDER_FILE"; then
  test_fail "Missing 'flex: 1' CSS property in .unified-tab"
fi

if ! grep -q "text-align: center;" "$PROVIDER_FILE"; then
  test_fail "Missing 'text-align: center' CSS property in .unified-tab"
fi

if ! grep -q "white-space: nowrap;" "$PROVIDER_FILE"; then
  test_fail "Missing 'white-space: nowrap' CSS property in .unified-tab"
fi

if ! grep -q "overflow: hidden;" "$PROVIDER_FILE"; then
  test_fail "Missing 'overflow: hidden' CSS property in .unified-tab"
fi

if ! grep -q "text-overflow: ellipsis;" "$PROVIDER_FILE"; then
  test_fail "Missing 'text-overflow: ellipsis' CSS property in .unified-tab"
fi

# Verify properties are within .unified-tab context (not in other classes)
# Extract the .unified-tab CSS block and verify all properties are present
TAB_BLOCK=$(sed -n '/\.unified-tab {/,/^    }$/p' "$PROVIDER_FILE" | head -n 20)

if ! echo "$TAB_BLOCK" | grep -q "flex: 1"; then
  test_fail "'flex: 1' not found within .unified-tab CSS block"
fi

if ! echo "$TAB_BLOCK" | grep -q "text-align: center"; then
  test_fail "'text-align: center' not found within .unified-tab CSS block"
fi

if ! echo "$TAB_BLOCK" | grep -q "white-space: nowrap"; then
  test_fail "'white-space: nowrap' not found within .unified-tab CSS block"
fi

if ! echo "$TAB_BLOCK" | grep -q "overflow: hidden"; then
  test_fail "'overflow: hidden' not found within .unified-tab CSS block"
fi

if ! echo "$TAB_BLOCK" | grep -q "text-overflow: ellipsis"; then
  test_fail "'text-overflow: ellipsis' not found within .unified-tab CSS block"
fi

test_pass "Tab styling CSS properties verified"
