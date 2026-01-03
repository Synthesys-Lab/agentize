#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with gh pr create (publish operation)

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with gh pr create (publish operation)"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Create pull request" '{"command": "gh pr create --title \"test\""}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "ask" || "$result" == "deny" ]]; then
    test_pass "PR creation not auto-allowed ($result)"
else
    test_fail "Expected 'ask' or 'deny', got '$result'"
fi
