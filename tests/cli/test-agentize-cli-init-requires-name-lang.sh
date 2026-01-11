#!/usr/bin/env bash
# Test: apply --init requires --name and --lang flags

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "apply --init requires --name and --lang flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Missing both flags (apply with --init but no name/lang)
if lol apply --init 2>/dev/null; then
  test_fail "Should require --name and --lang"
fi

# Missing --lang
if lol apply --init --name test 2>/dev/null; then
  test_fail "Should require --lang"
fi

# Missing --name
if lol apply --init --lang python 2>/dev/null; then
  test_fail "Should require --name"
fi

test_pass "Correctly requires --name and --lang"
