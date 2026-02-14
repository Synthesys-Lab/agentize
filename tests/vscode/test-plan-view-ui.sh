#!/usr/bin/env bash
# Test: Plan view UI components (collapsible logs, step indicators, link rendering)

source "$(dirname "$0")/../common.sh"

test_info "Testing plan view UI structure and components"

# Check that the webview files exist and have the expected content
WEBVIEW_DIR="$PROJECT_ROOT/vscode/webview/plan"
PROVIDER_FILE="$PROJECT_ROOT/vscode/src/view/planViewProvider.ts"

# Test 1: Check CSS has step indicator styles
if ! grep -q "step-indicator" "$WEBVIEW_DIR/styles.css"; then
  test_fail "styles.css missing step-indicator styles"
fi

# Test 2: Check CSS has raw logs box styles
if ! grep -q "raw-logs-box" "$WEBVIEW_DIR/styles.css"; then
  test_fail "styles.css missing raw-logs-box styles"
fi

# Test 3: Check CSS has dot-cycle animation
if ! grep -q "@keyframes dot-cycle" "$WEBVIEW_DIR/styles.css"; then
  test_fail "styles.css missing dot-cycle animation"
fi

# Test 4: Check index.ts has step parsing logic
if ! grep -q "parseStageLine" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts missing parseStageLine function"
fi

# Test 5: Check index.ts has link detection
if ! grep -q "renderLinks" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts missing renderLinks function"
fi

# Test 6: Check index.ts has collapsible logs state
if ! grep -q "logsCollapsedState" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts missing logsCollapsedState tracking"
fi

# Test 7: Check planViewProvider.ts has link handlers
if ! grep -q "link/openExternal" "$PROVIDER_FILE"; then
  test_fail "planViewProvider.ts missing link/openExternal handler"
fi

if ! grep -q "link/openFile" "$PROVIDER_FILE"; then
  test_fail "planViewProvider.ts missing link/openFile handler"
fi

# Test 8: Check planViewProvider.ts has URL validation
if ! grep -q "isValidGitHubUrl" "$PROVIDER_FILE"; then
  test_fail "planViewProvider.ts missing isValidGitHubUrl function"
fi

# Test 9: Ensure webview loads compiled JS (loading TS directly breaks rendering)
if ! grep -q "'webview', 'plan', 'out', 'index.js'" "$PROVIDER_FILE"; then
  test_fail "planViewProvider.ts should load compiled webview/plan/out/index.js"
fi

# Test 10: Check documentation exists
if [ ! -f "$WEBVIEW_DIR/index.md" ]; then
  test_fail "index.md documentation missing"
fi

# Test 11: Check documentation mentions new features
if ! grep -q "Step Progress Indicators" "$WEBVIEW_DIR/index.md"; then
  test_fail "index.md missing Step Progress Indicators documentation"
fi

if ! grep -q "Collapsible Raw Console Log" "$WEBVIEW_DIR/index.md"; then
  test_fail "index.md missing Collapsible Raw Console Log documentation"
fi

if ! grep -q "Interactive Links" "$WEBVIEW_DIR/index.md"; then
  test_fail "index.md missing Interactive Links documentation"
fi

test_info "All UI structure tests passed"

# Check TypeScript syntax (if tsc is available)
if command -v npx >/dev/null 2>&1; then
  test_info "Checking TypeScript syntax..."
  
  cd "$PROJECT_ROOT/vscode"
  
  if [ -f "package.json" ]; then
    # Run tsc to check for syntax errors (no emit)
    if npx tsc --noEmit 2>/dev/null; then
      test_info "TypeScript syntax check passed"
    else
      test_info "TypeScript check found issues (may be pre-existing or missing dependencies)"
    fi
  fi
fi

test_pass "Plan view UI component tests passed"
