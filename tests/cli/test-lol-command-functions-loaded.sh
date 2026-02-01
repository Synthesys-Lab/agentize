#!/usr/bin/env bash
# Test: Private _lol_* functions are available and public lol_cmd_* are absent

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "Private _lol_* helpers are available and lol_cmd_* helpers are absent"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# List of expected command functions
EXPECTED_FUNCTIONS=(
    "_lol_cmd_upgrade"
    "_lol_cmd_use_branch"
    "_lol_cmd_version"
    "_lol_cmd_project"
    "_lol_cmd_serve"
    "_lol_cmd_claude_clean"
    "_lol_cmd_usage"
    "_lol_cmd_plan"
    "_lol_cmd_impl"
    "_lol_complete"
    "_lol_detect_lang"
)

# Check each function is defined (shell-agnostic approach)
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    # Use 'type' output which works in both bash and zsh
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function '$func' is not defined after sourcing lol.sh"
    fi
done

DISALLOWED_FUNCTIONS=(
    "lol_cmd_upgrade"
    "lol_cmd_use_branch"
    "lol_cmd_version"
    "lol_cmd_project"
    "lol_cmd_serve"
    "lol_cmd_claude_clean"
    "lol_cmd_usage"
    "lol_cmd_plan"
    "lol_cmd_impl"
    "lol_complete"
    "lol_detect_lang"
)

for func in "${DISALLOWED_FUNCTIONS[@]}"; do
    if type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function '$func' should not be public after sourcing lol.sh"
    fi
done

test_pass "All ${#EXPECTED_FUNCTIONS[@]} _lol_* functions are available and public lol_cmd_* helpers are absent"
