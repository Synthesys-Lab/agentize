#!/usr/bin/env bash
# Test: lol init --metadata-only still requires --name and --lang

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol init --metadata-only still requires --name and --lang"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Missing both flags
if lol init --metadata-only 2>/dev/null; then
  test_fail "metadata-only should require --name and --lang"
fi

# Missing --lang
if lol init --name test --metadata-only 2>/dev/null; then
  test_fail "metadata-only should require --lang"
fi

# Missing --name
if lol init --lang python --metadata-only 2>/dev/null; then
  test_fail "metadata-only should require --name"
fi

test_pass "metadata-only mode correctly requires --name and --lang"
