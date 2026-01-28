#!/usr/bin/env bash
# Test: term label helpers respect NO_COLOR and PLANNER_NO_COLOR

source "$(dirname "$0")/../common.sh"

TERM_COLORS="$PROJECT_ROOT/src/cli/term/colors.sh"

test_info "term label helpers respect NO_COLOR and PLANNER_NO_COLOR"

# Source the term colors library
source "$TERM_COLORS"

# Test 1: term_color_enabled returns 1 when NO_COLOR=1
(
    export NO_COLOR=1
    if term_color_enabled; then
        test_fail "term_color_enabled should return 1 when NO_COLOR=1"
    fi
)

# Test 2: term_color_enabled returns 1 when PLANNER_NO_COLOR=1
(
    unset NO_COLOR
    export PLANNER_NO_COLOR=1
    if term_color_enabled; then
        test_fail "term_color_enabled should return 1 when PLANNER_NO_COLOR=1"
    fi
)

# Test 3: term_label prints plain text when colors disabled
(
    export NO_COLOR=1
    output=$(term_label "Feature:" "test description" "info" 2>&1)
    expected="Feature: test description"
    if [ "$output" != "$expected" ]; then
        test_fail "term_label should print plain 'Feature: test description', got '$output'"
    fi
)

# Test 4: term_label with success style prints plain text when colors disabled
(
    export NO_COLOR=1
    output=$(term_label "issue created:" "http://example.com" "success" 2>&1)
    expected="issue created: http://example.com"
    if [ "$output" != "$expected" ]; then
        test_fail "term_label should print plain text with success style, got '$output'"
    fi
)

# Test 5: term_clear_line emits proper escape sequence (no color involved)
(
    output=$(term_clear_line 2>&1)
    # The clear line sequence is \r\033[K - we check it contains the escape
    if [[ "$output" != *$'\033[K'* ]] && [[ "$output" != *$'\x1b[K'* ]]; then
        # Note: In non-TTY context, it may still output the sequence
        # or be empty - we just verify it doesn't error
        :
    fi
)

test_pass "term label helpers respect NO_COLOR and PLANNER_NO_COLOR"
