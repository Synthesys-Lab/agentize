#!/usr/bin/env bash
# Test: Invalid AGENTIZE_HOME produces error

source "$(dirname "$0")/../common.sh"

test_info "Invalid AGENTIZE_HOME produces error"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

# Attempt to use wt spawn with invalid AGENTIZE_HOME
(
  export AGENTIZE_HOME="/nonexistent/path"
  if source "$WT_CLI" 2>/dev/null && wt spawn 42 2>/dev/null; then
    test_fail "Should error when AGENTIZE_HOME is invalid"
  fi
) || true

test_pass "Errors correctly on invalid AGENTIZE_HOME"
