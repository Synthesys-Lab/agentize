#!/usr/bin/env bash
# Test: CLAUDE_HANDSOFF=true with git commit

source "$(dirname "$0")/../common.sh"

test_info "CLAUDE_HANDSOFF=true with git commit"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

export CLAUDE_HANDSOFF=true

result=$("$HOOK_SCRIPT" "Bash" "Create commit" '{"command": "git commit -m \"test\""}')

unset CLAUDE_HANDSOFF

if [[ "$result" == "allow" ]]; then
    test_pass "Git commit auto-allowed in hands-off mode"
else
    test_fail "Expected 'allow', got '$result'"
fi
