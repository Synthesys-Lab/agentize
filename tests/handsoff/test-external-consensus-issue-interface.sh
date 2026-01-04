#!/usr/bin/env bash
# Test: external-consensus.sh issue-number and path modes argument parsing

source "$(dirname "$0")/../common.sh"

# Override PROJECT_ROOT to use current worktree instead of AGENTIZE_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel)

test_info "Testing external-consensus.sh argument parsing for issue-number and path modes"

# Setup: Create test debate reports
ISSUE_NUMBER=42
DEBATE_REPORT_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-debate.md"

mkdir -p "$PROJECT_ROOT/.tmp"
cat > "$DEBATE_REPORT_FILE" << 'EOF'
# Multi-Agent Debate Report

**Feature**: Test Feature
**Generated**: 2026-01-04 12:00

This document combines three perspectives from our multi-agent debate-based planning system.
EOF

# Test Case 1: Verify issue-number mode resolves correct path
test_info "Test 1: Issue-number mode path resolution"

# The script should try to read .tmp/issue-42-debate.md when given "42"
# We verify this by checking that it doesn't fail with "file not found" error
if timeout 2 "$PROJECT_ROOT/.claude/skills/external-consensus/scripts/external-consensus.sh" "$ISSUE_NUMBER" 2>&1 | grep -q "Error: Debate report file not found"; then
    test_fail "Issue-number mode: script failed to find debate report at expected path"
fi

# If the script proceeds past the file check (which it should since we created the file),
# it will start the external review process. We timeout after 2 seconds, which is expected.
test_info "✓ Issue-number mode resolved .tmp/issue-{N}-debate.md correctly"

# Test Case 2: Verify path mode accepts explicit paths
test_info "Test 2: Path mode with explicit debate report path"

PATH_DEBATE_REPORT="$PROJECT_ROOT/.tmp/custom-debate-report.md"
cp "$DEBATE_REPORT_FILE" "$PATH_DEBATE_REPORT"

if timeout 2 "$PROJECT_ROOT/.claude/skills/external-consensus/scripts/external-consensus.sh" "$PATH_DEBATE_REPORT" 2>&1 | grep -q "Error: Debate report file not found: $PATH_DEBATE_REPORT"; then
    test_fail "Path mode: script rejected valid debate report path"
fi

test_info "✓ Path mode accepted explicit debate report path"

# Test Case 3: Error handling for missing debate report
test_info "Test 3: Error handling for missing debate report in issue-number mode"

MISSING_ISSUE=999
rm -f "$PROJECT_ROOT/.tmp/issue-${MISSING_ISSUE}-debate.md"

# The script should exit with error and show the resolved path
if "$PROJECT_ROOT/.claude/skills/external-consensus/scripts/external-consensus.sh" "$MISSING_ISSUE" 2>&1 | grep -q "issue-${MISSING_ISSUE}-debate.md"; then
    test_info "✓ Error message shows resolved path for missing file"
else
    test_fail "Expected error message not shown"
fi

# Test Case 4: Usage message documents both modes
test_info "Test 4: Usage message includes both modes"

if "$PROJECT_ROOT/.claude/skills/external-consensus/scripts/external-consensus.sh" 2>&1 | grep -q "issue-number|debate-report-path"; then
    test_info "✓ Usage message documents both issue-number and path modes"
else
    test_fail "Usage message missing dual-mode documentation"
fi

# Cleanup
rm -f "$DEBATE_REPORT_FILE" "$PATH_DEBATE_REPORT"
pkill -9 -f "codex exec" 2>/dev/null || true

test_pass "All external-consensus argument parsing tests passed"
