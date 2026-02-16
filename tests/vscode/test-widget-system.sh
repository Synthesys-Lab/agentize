#!/usr/bin/env bash
# Test: Widget append-based session UI scaffolding

source "$(dirname "$0")/../common.sh"

test_info "Testing widget system scaffolding"

WEBVIEW_DIR="$PROJECT_ROOT/vscode/webview/plan"
STATE_TYPES_FILE="$PROJECT_ROOT/vscode/src/state/types.ts"
SESSION_STORE_FILE="$PROJECT_ROOT/vscode/src/state/sessionStore.ts"
STYLE_FILE="$WEBVIEW_DIR/styles.css"
INDEX_FILE="$WEBVIEW_DIR/index.ts"
TYPES_FILE="$WEBVIEW_DIR/types.ts"

# Test 1: Widget helper module exists
if [ ! -f "$WEBVIEW_DIR/widgets.ts" ]; then
  test_fail "widgets.ts missing"
fi

# Test 2: Widget interface documentation exists
if [ ! -f "$WEBVIEW_DIR/widgets.md" ]; then
  test_fail "widgets.md missing"
fi

# Test 3: Webview message types include widget append/update
if ! grep -q "widget/append" "$TYPES_FILE"; then
  test_fail "types.ts missing widget/append message"
fi

if ! grep -q "widget/update" "$TYPES_FILE"; then
  test_fail "types.ts missing widget/update message"
fi

# Test 4: State types include widget timeline fields
if ! grep -q "widgets" "$STATE_TYPES_FILE"; then
  test_fail "types.ts missing widgets field"
fi

if ! grep -q "WidgetState" "$STATE_TYPES_FILE"; then
  test_fail "types.ts missing WidgetState type"
fi

# Test 5: SessionStore has migration helper
if ! grep -q "migrateSession" "$SESSION_STORE_FILE"; then
  test_fail "sessionStore.ts missing migrateSession helper"
fi

# Test 6: Webview handles widget append messages
if ! grep -q "widget/append" "$INDEX_FILE"; then
  test_fail "index.ts missing widget/append handling"
fi

# Test 7: Styles include widget base class
if ! grep -q "\.widget" "$STYLE_FILE"; then
  test_fail "styles.css missing widget styles"
fi

test_pass "Widget system scaffolding tests passed"
