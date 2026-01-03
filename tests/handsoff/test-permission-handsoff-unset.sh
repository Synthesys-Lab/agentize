#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF unset with safe read operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF unset with safe read operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

unset CLAUDE_HANDSOFF

result=$("$HOOK_SCRIPT" "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

if [[ "$result" == "ask" ]]; then
    test_pass "Unset env var results in 'ask' (fail-closed)"
else
    test_fail "Expected 'ask', got '$result'"
fi
