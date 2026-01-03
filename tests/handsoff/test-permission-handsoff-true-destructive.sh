#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with destructive operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with destructive operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Delete all files" '{"command": "rm -rf /"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "deny" || "$result" == "ask" ]]; then
    test_pass "Destructive operation not auto-allowed ($result)"
else
    test_fail "Expected 'deny' or 'ask', got '$result'"
fi
