#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=TRUE (case-insensitive)

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=TRUE (case-insensitive)"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=TRUE

result=$("$HOOK_SCRIPT" "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Case-insensitive parsing works"
else
    test_fail "Expected 'allow', got '$result'"
fi
