#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with safe git command

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with safe git command"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Check git status" '{"command": "git status"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Safe git command auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
