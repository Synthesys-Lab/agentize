#!/usr/bin/env bash
# Test: acw completion functionality
# Verifies acw --complete returns expected values for each topic

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw completion functionality"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Test 1: acw --complete providers returns all providers
test_info "Checking --complete providers"
providers_output=$(acw --complete providers)

for provider in claude codex opencode cursor; do
    if ! echo "$providers_output" | grep -q "^${provider}$"; then
        test_fail "Provider '$provider' not found in --complete providers output"
    fi
done

# Test 2: acw --complete cli-options returns common flags
test_info "Checking --complete cli-options"
options_output=$(acw --complete cli-options)

for option in "--help" "--editor" "--stdout" "--model" "--yolo"; do
    if ! echo "$options_output" | grep -q "^${option}$"; then
        test_fail "Option '$option' not found in --complete cli-options output"
    fi
done

# Test 3: acw --complete with unknown topic returns empty (graceful degradation)
test_info "Checking --complete with unknown topic"
unknown_output=$(acw --complete unknown-topic 2>/dev/null)

if [ -n "$unknown_output" ]; then
    test_fail "Expected empty output for unknown completion topic, got: $unknown_output"
fi

# Test 4: _acw_complete function is available (private)
test_info "Checking _acw_complete function exists"
if ! type _acw_complete 2>/dev/null | grep -q "function"; then
    test_fail "_acw_complete function is not defined"
fi

# Test 5: old acw_complete function is NOT available
test_info "Checking old acw_complete function is removed"
if type acw_complete 2>/dev/null | grep -q "function"; then
    test_fail "Old acw_complete function should be renamed to _acw_complete"
fi

test_pass "All completion tests passed"
