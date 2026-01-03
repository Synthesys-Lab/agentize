#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=invalid with safe read operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=invalid with safe read operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=maybe

result=$("$HOOK_SCRIPT" "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "ask" ]]; then
    test_pass "Invalid value treated as disabled (fail-closed)"
else
    test_fail "Expected 'ask', got '$result'"
fi
