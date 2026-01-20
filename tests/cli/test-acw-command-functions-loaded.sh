#!/usr/bin/env bash
# Test: All acw_* functions are available after sourcing acw.sh

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "All acw_* functions are available after sourcing acw.sh"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# List of expected functions
EXPECTED_FUNCTIONS=(
    "acw"
    "acw_invoke_claude"
    "acw_invoke_codex"
    "acw_invoke_opencode"
    "acw_invoke_cursor"
    "acw_validate_args"
    "acw_check_cli"
    "acw_ensure_output_dir"
)

# Check each function is defined (shell-agnostic approach)
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    # Use 'type' output which works in both bash and zsh
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function '$func' is not defined after sourcing acw.sh"
    fi
done

test_pass "All ${#EXPECTED_FUNCTIONS[@]} acw_* functions are available"
