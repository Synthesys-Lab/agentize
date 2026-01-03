#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with git push (publish operation)

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with git push (publish operation)"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Push to remote" '{"command": "git push"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "ask" || "$result" == "deny" ]]; then
    test_pass "Git push not auto-allowed ($result)"
else
    test_fail "Expected 'ask' or 'deny', got '$result'"
fi
