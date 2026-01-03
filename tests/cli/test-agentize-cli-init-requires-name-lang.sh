#!/usr/bin/env bash
# Test: init requires --name and --lang flags

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "init requires --name and --lang flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Missing both flags
if lol init 2>/dev/null; then
  test_fail "Should require --name and --lang"
fi

# Missing --lang
if lol init --name test 2>/dev/null; then
  test_fail "Should require --lang"
fi

# Missing --name
if lol init --lang python 2>/dev/null; then
  test_fail "Should require --name"
fi

test_pass "Correctly requires --name and --lang"
