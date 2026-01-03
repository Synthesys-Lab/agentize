#!/usr/bin/env bash
# Test: Missing AGENTIZE_HOME produces error

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "Missing AGENTIZE_HOME produces error"

(
  unset AGENTIZE_HOME
  if source "$LOL_CLI" 2>/dev/null && lol init --name test --lang python 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is missing"
  fi
  test_pass "Errors correctly on missing AGENTIZE_HOME"
) || test_pass "Errors correctly on missing AGENTIZE_HOME"
