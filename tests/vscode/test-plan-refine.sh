#!/usr/bin/env bash
# Test: Plan refine wiring (webview action, message handler, command builder)

source "$(dirname "$0")/../common.sh"

test_info "Testing plan refine wiring"

RUNNER_FILE="$PROJECT_ROOT/vscode/src/runner/planRunner.ts"
TYPES_FILE="$PROJECT_ROOT/vscode/src/runner/types.ts"
VIEW_FILE="$PROJECT_ROOT/vscode/src/view/unifiedViewProvider.ts"
WEBVIEW_FILE="$PROJECT_ROOT/vscode/webview/plan/index.ts"

# Test 1: RunPlanInput includes refineIssueNumber
if ! grep -q "refineIssueNumber" "$TYPES_FILE"; then
  test_fail "RunPlanInput missing refineIssueNumber"
fi

# Test 2: PlanRunner buildCommand handles refine mode
if ! grep -q -- "--refine" "$RUNNER_FILE"; then
  test_fail "planRunner.ts missing --refine flag handling"
fi

if ! grep -q "refineIssueNumber" "$RUNNER_FILE"; then
  test_fail "planRunner.ts missing refineIssueNumber usage"
fi

if ! grep -q "args.push(prompt)" "$RUNNER_FILE"; then
  test_fail "planRunner.ts missing fallback args for non-refine runs"
fi

# Test 3: PlanViewProvider handles plan/refine messages
if ! grep -q "plan/refine" "$VIEW_FILE"; then
  test_fail "unifiedViewProvider.ts missing plan/refine handler"
fi

# Test 4: Webview posts plan/refine from session actions
if ! grep -q "plan/refine" "$WEBVIEW_FILE"; then
  test_fail "index.ts missing plan/refine message posting"
fi

# Test 5: Webview uses inline refine input widget flow
if ! grep -q "openRefineInput" "$WEBVIEW_FILE"; then
  test_fail "index.ts missing openRefineInput helper"
fi

if ! grep -q "appendInputWidget" "$WEBVIEW_FILE"; then
  test_fail "index.ts missing appendInputWidget usage for refine flow"
fi

test_pass "Plan refine wiring tests passed"
