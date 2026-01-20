#!/usr/bin/env bash
# Test: Only public acw_* functions are exposed after sourcing acw.sh
# Private helper functions should be prefixed with _acw_ and not appear in public API

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw public API - only public functions should be exposed"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# List of expected PUBLIC functions (only acw is public)
EXPECTED_PUBLIC_FUNCTIONS=(
    "acw"
)

# List of PRIVATE functions that should exist but be prefixed with _acw_
EXPECTED_PRIVATE_FUNCTIONS=(
    "_acw_validate_args"
    "_acw_check_cli"
    "_acw_ensure_output_dir"
    "_acw_check_input_file"
    "_acw_invoke_claude"
    "_acw_invoke_codex"
    "_acw_invoke_opencode"
    "_acw_invoke_cursor"
    "_acw_complete"
)

# Check each public function is defined
test_info "Checking public functions exist"
for func in "${EXPECTED_PUBLIC_FUNCTIONS[@]}"; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Public function '$func' is not defined after sourcing acw.sh"
    fi
done

# Check each private function is defined (with underscore prefix)
test_info "Checking private functions exist with _acw_ prefix"
for func in "${EXPECTED_PRIVATE_FUNCTIONS[@]}"; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Private function '$func' is not defined after sourcing acw.sh"
    fi
done

# Verify old public helpers are NOT available (should be renamed to _acw_)
test_info "Checking old acw_* helper names are removed"
OLD_HELPER_NAMES=(
    "acw_validate_args"
    "acw_check_cli"
    "acw_ensure_output_dir"
    "acw_check_input_file"
    "acw_invoke_claude"
    "acw_invoke_codex"
    "acw_invoke_opencode"
    "acw_invoke_cursor"
    "acw_complete"
)

for func in "${OLD_HELPER_NAMES[@]}"; do
    if type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Old helper '$func' should be renamed to '_$func' but still exists"
    fi
done

test_pass "Public API has ${#EXPECTED_PUBLIC_FUNCTIONS[@]} functions, ${#EXPECTED_PRIVATE_FUNCTIONS[@]} private helpers correctly prefixed"
