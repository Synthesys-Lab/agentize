#!/usr/bin/env bash
# Test: All lol_cmd_* functions are available after sourcing lol.sh

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "All lol_cmd_* functions are available after sourcing lol.sh"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# List of expected command functions
EXPECTED_FUNCTIONS=(
    "lol_cmd_init"
    "lol_cmd_update"
    "lol_cmd_upgrade"
    "lol_cmd_version"
    "lol_cmd_project"
    "lol_cmd_serve"
    "lol_cmd_claude_clean"
)

# Check each function is defined
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    if [ "$(type -t "$func")" != "function" ]; then
        test_fail "Function '$func' is not defined after sourcing lol.sh"
    fi
done

test_pass "All ${#EXPECTED_FUNCTIONS[@]} lol_cmd_* functions are available"
