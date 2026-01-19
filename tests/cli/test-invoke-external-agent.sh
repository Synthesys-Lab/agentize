#!/usr/bin/env bash
# Test: invoke-external-agent.sh wrapper script exists and is executable

source "$(dirname "$0")/../common.sh"

WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/invoke-external-agent.sh"

test_info "invoke-external-agent.sh wrapper tests"

# Test 1: Script exists
[ -f "$WRAPPER_SCRIPT" ] || test_fail "Script not found: $WRAPPER_SCRIPT"

# Test 2: Script is executable
[ -x "$WRAPPER_SCRIPT" ] || test_fail "Script not executable: $WRAPPER_SCRIPT"

test_pass "invoke-external-agent.sh wrapper exists and is executable"
