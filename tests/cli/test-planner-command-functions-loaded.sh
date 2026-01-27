#!/usr/bin/env bash
# Test: planner is public, _planner_* helpers are private

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner is public and _planner_* helpers exist after sourcing planner.sh"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"

# Verify the public function exists
if ! type "planner" 2>/dev/null | grep -q "function"; then
    test_fail "Function 'planner' is not defined after sourcing planner.sh"
fi

# Verify private helpers exist
PRIVATE_HELPERS=(
    "_planner_run_pipeline"
    "_planner_render_prompt"
    "_planner_issue_create"
    "_planner_issue_publish"
)

for func in "${PRIVATE_HELPERS[@]}"; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Private helper '$func' is not defined after sourcing planner.sh"
    fi
done

# Verify non-prefixed variants do NOT exist (they should be private)
if type "planner_run_pipeline" 2>/dev/null | grep -q "function"; then
    test_fail "Function 'planner_run_pipeline' should not be public (use _planner_run_pipeline)"
fi

test_pass "planner is public and ${#PRIVATE_HELPERS[@]} private helpers are available"
