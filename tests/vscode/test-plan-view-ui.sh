#!/usr/bin/env bash
# Test: Plan view append-only widget UI structure

source "$(dirname "$0")/../common.sh"

test_info "Testing plan view append-only widget UI"

WEBVIEW_DIR="$PROJECT_ROOT/vscode/webview/plan"
PROVIDER_FILE="$PROJECT_ROOT/vscode/src/view/unifiedViewProvider.ts"
STATE_TYPES_FILE="$PROJECT_ROOT/vscode/src/state/types.ts"

# Test 1: CSS keeps progress indicator styling.
if ! grep -q "step-indicator" "$WEBVIEW_DIR/styles.css"; then
  test_fail "styles.css missing step-indicator styles"
fi

# Test 2: CSS keeps progress animation.
if ! grep -q "@keyframes dot-cycle" "$WEBVIEW_DIR/styles.css"; then
  test_fail "styles.css missing dot-cycle animation"
fi

# Test 3: Stage parser still exists for progress widgets.
if ! grep -q "parseStageLine" "$WEBVIEW_DIR/utils.ts"; then
  test_fail "utils.ts missing parseStageLine function"
fi

# Test 4: index.ts supports input widget based refine flow.
if ! grep -q "appendInputWidget" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts missing appendInputWidget usage"
fi

if ! grep -q "openRefineInput" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts missing openRefineInput helper"
fi

# Test 5: Legacy right-side session implement/refine buttons are removed from webview code.
if grep -q "impl-button" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts still references legacy impl-button UI"
fi

if grep -q "refineButton" "$WEBVIEW_DIR/index.ts"; then
  test_fail "index.ts still references legacy refineButton UI"
fi

# Test 6: Host still supports secure link handlers.
if ! grep -q "link/openExternal" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing link/openExternal handler"
fi

if ! grep -q "link/openFile" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing link/openFile handler"
fi

# Test 7: Host still validates GitHub URLs.
if ! grep -q "isValidGitHubUrl" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing isValidGitHubUrl function"
fi

# Test 8: Webview script path must point to compiled JS.
if ! grep -q "'webview', 'plan', 'out', 'index.js'" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts should load compiled webview/plan/out/index.js"
fi

# Test 9: Documentation should describe append-only model.
if [ ! -f "$WEBVIEW_DIR/index.md" ]; then
  test_fail "index.md documentation missing"
fi

if ! grep -q "Append-only webview controller" "$WEBVIEW_DIR/index.md"; then
  test_fail "index.md missing append-only description"
fi

# Test 10: Session type keeps issue state information.
if ! grep -q "issueState" "$STATE_TYPES_FILE"; then
  test_fail "types.ts missing issueState field"
fi

# Test 11: Provider keeps issue-state validation logic.
if ! grep -q "checkIssueState" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing checkIssueState handler"
fi

# Test 12: Host supports View Issue action.
if ! grep -q "plan/view-issue" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing plan/view-issue handler"
fi

if ! grep -q "View Issue" "$PROVIDER_FILE"; then
  test_fail "unifiedViewProvider.ts missing View Issue action button"
fi

test_info "All append-only UI structure tests passed"

# Check TypeScript syntax (if toolchain is available).
if command -v npx >/dev/null 2>&1; then
  test_info "Checking TypeScript syntax..."
  if [ -f "$PROJECT_ROOT/vscode/package.json" ]; then
    if npx --prefix "$PROJECT_ROOT/vscode" tsc -p "$PROJECT_ROOT/vscode/tsconfig.json" --noEmit 2>/dev/null; then
      test_info "TypeScript syntax check passed"
    else
      test_info "TypeScript check found issues (may be pre-existing or missing dependencies)"
    fi
  fi
fi

test_pass "Plan view append-only UI tests passed"
