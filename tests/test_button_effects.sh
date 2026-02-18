#!/bin/bash
# Test button tactile interaction effects
# Verifies CSS interaction properties exist in VSCode webview stylesheets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLAN_CSS="$PROJECT_ROOT/vscode/webview/plan/styles.css"
SETTINGS_CSS="$PROJECT_ROOT/vscode/webview/settings/styles.css"

ERRORS=0

echo "=== Testing Button Tactile Effects ==="
echo ""

# Test 1: Base button hover state
echo -n "Test 1: Base button has :hover state... "
if grep -q "button:hover" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 2: Base button active state
echo -n "Test 2: Base button has :active state... "
if grep -q "button:active" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 3: Base button transition property
echo -n "Test 3: Base button has transition property... "
if grep -A12 "^button {" "$PLAN_CSS" | grep -q "transition:"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 4: Widget button variants have hover state
echo -n "Test 4: Widget buttons have :hover state... "
if grep -q "\.widget-button:hover" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 5: Widget button variants have active state
echo -n "Test 5: Widget buttons have :active state... "
if grep -q "\.widget-button:active" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 6: Icon buttons (toggle) have hover state
echo -n "Test 6: Toggle buttons have :hover state... "
if grep -q "\.toggle:hover" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 7: Icon buttons (toggle) have active state
echo -n "Test 7: Toggle buttons have :active state... "
if grep -q "\.toggle:active" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 8: Terminal toggle has hover state
echo -n "Test 8: Terminal toggle has :hover state... "
if grep -q "\.terminal-toggle:hover" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 9: Terminal toggle has active state
echo -n "Test 9: Terminal toggle has :active state... "
if grep -q "\.terminal-toggle:active" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 10: Settings link has active state
echo -n "Test 10: Settings link has :active state... "
if grep -q "\.settings-link:active" "$SETTINGS_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 11: prefers-reduced-motion media query in plan/styles.css
echo -n "Test 11: prefers-reduced-motion in plan/styles.css... "
if grep -q "prefers-reduced-motion" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 12: prefers-reduced-motion media query in settings/styles.css
echo -n "Test 12: prefers-reduced-motion in settings/styles.css... "
if grep -q "prefers-reduced-motion" "$SETTINGS_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

# Test 13: 120ms transition timing
echo -n "Test 13: Transition timing is 120ms... "
if grep -q "120ms" "$PLAN_CSS"; then
  echo "PASS"
else
  echo "FAIL"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "=== All tests passed! ==="
  exit 0
else
  echo "=== $ERRORS test(s) failed ==="
  exit 1
fi
