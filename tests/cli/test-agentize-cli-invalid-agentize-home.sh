#!/usr/bin/env bash
# Test: Invalid AGENTIZE_HOME produces error

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "Invalid AGENTIZE_HOME produces error"

(
  export AGENTIZE_HOME="/nonexistent/path"
  if source "$LOL_CLI" 2>/dev/null && lol init --name test --lang python 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is invalid"
  fi
  test_pass "Errors correctly on invalid AGENTIZE_HOME"
) || test_pass "Errors correctly on invalid AGENTIZE_HOME"
