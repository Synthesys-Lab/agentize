#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=false with Edit operation

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=false with Edit operation"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=false

result=$("$HOOK_SCRIPT" "Edit" "Update configuration file" '{"file_path": "/tmp/test.txt", "old_string": "foo", "new_string": "bar"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "ask" ]]; then
    test_pass "Edit asks permission when hands-off is disabled"
else
    test_fail "Expected 'ask', got '$result'"
fi
