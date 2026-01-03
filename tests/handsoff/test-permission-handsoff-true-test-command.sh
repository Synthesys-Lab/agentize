#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with test command

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with test command"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Run tests" '{"command": "make test"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Test command auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
