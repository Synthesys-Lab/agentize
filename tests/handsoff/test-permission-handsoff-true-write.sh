#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with Write operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with Write operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Write" "Create new file" '{"file_path": "/tmp/test.txt", "content": "test content"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Write auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
