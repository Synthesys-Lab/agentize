#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=false with safe read operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=false with safe read operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=false

result=$("$HOOK_SCRIPT" "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "ask" ]]; then
    test_pass "Safe read asks permission when hands-off is disabled"
else
    test_fail "Expected 'ask', got '$result'"
fi
