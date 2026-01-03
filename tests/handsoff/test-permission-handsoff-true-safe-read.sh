#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with safe read operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with safe read operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Safe read auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
