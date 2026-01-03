#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with Edit operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with Edit operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Edit" "Update configuration file" '{"file_path": "/tmp/test.txt", "old_string": "foo", "new_string": "bar"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Edit auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
