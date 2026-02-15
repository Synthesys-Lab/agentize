#!/usr/bin/env bash
# Test: Plan refine wiring (webview action, message handler, command builder)

source "$(dirname "$0")/../common.sh"

test_info "Testing plan refine wiring"

RUNNER_FILE="$PROJECT_ROOT/vscode/src/runner/planRunner.ts"
TYPES_FILE="$PROJECT_ROOT/vscode/src/runner/types.ts"
VIEW_FILE="$PROJECT_ROOT/vscode/src/view/planViewProvider.ts"
WEBVIEW_FILE="$PROJECT_ROOT/vscode/webview/plan/index.ts"
STYLE_FILE="$PROJECT_ROOT/vscode/webview/plan/styles.css"

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
  test_fail "planViewProvider.ts missing plan/refine handler"
fi

# Test 4: Webview posts plan/refine from session actions
if ! grep -q "plan/refine" "$WEBVIEW_FILE"; then
  test_fail "index.ts missing plan/refine message posting"
fi

# Test 5: Webview styles include refine button
if ! grep -q "\.refine" "$STYLE_FILE"; then
  test_fail "styles.css missing .refine button styling"
fi

test_pass "Plan refine wiring tests passed"
