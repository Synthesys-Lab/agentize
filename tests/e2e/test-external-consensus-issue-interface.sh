#!/usr/bin/env bash
# Test: external-consensus.sh 3-report-path argument parsing

source "$(dirname "$0")/../common.sh"

# Override PROJECT_ROOT to use current worktree instead of AGENTIZE_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel)

test_info "Testing external-consensus.sh argument parsing for 3-report-path mode"

# Setup: Create test agent reports
ISSUE_NUMBER=42
REPORT1_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-bold-proposal.md"
REPORT2_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-critique.md"
REPORT3_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-reducer.md"

mkdir -p "$PROJECT_ROOT/.tmp"
cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

**Feature**: Test Feature

This is a bold proposal for the test feature.
EOF

cat > "$REPORT2_FILE" << 'EOF'
# Critique Report

This is a critique of the bold proposal.
EOF

cat > "$REPORT3_FILE" << 'EOF'
# Reducer Report

This is a simplified version of the proposal.
EOF

# Test Case 1: Verify script requires exactly 3 arguments
test_info "Test 1: Script requires exactly 3 arguments"

if "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$REPORT2_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_info "✓ Script correctly rejects 2 arguments"
else
    test_fail "Script should reject 2 arguments"
fi

if "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_info "✓ Script correctly rejects 1 argument"
else
    test_fail "Script should reject 1 argument"
fi

# Test Case 2: Verify script accepts 3 valid report paths
test_info "Test 2: Script accepts 3 valid report paths"

# The script should accept 3 valid paths and proceed to combining them
# We verify this by checking that it doesn't fail with "required" error
if timeout 2 "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_fail "Script rejected valid 3-argument invocation"
fi

test_info "✓ Script accepted 3 valid report paths"

# Test Case 3: Verify script validates all 3 files exist
test_info "Test 3: Script validates all report files exist"

MISSING_REPORT="$PROJECT_ROOT/.tmp/missing-report.md"
rm -f "$MISSING_REPORT"

if "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$MISSING_REPORT" "$REPORT3_FILE" 2>&1 | grep -q "Error: Report file not found: $MISSING_REPORT"; then
    test_info "✓ Script correctly detects missing second report"
else
    test_fail "Expected error for missing report file"
fi

# Test Case 4: Verify script creates combined debate report
test_info "Test 4: Script combines reports into debate report"

# Pre-clean the debate report to ensure it's created fresh
DEBATE_REPORT="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-debate.md"
rm -f "$DEBATE_REPORT"

# Run the script in background and kill it after debate report creation
# The script will continue to external review, but we only care about the debate report
(
    "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

# Wait up to 5 seconds for the debate report to be created
for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

# Kill the script process (it would be trying to invoke Codex/Claude)
kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

# Verify the debate report was created
if [ -f "$DEBATE_REPORT" ]; then
    test_info "✓ Debate report file created at expected path"

    # Verify it contains content from all 3 reports
    if grep -q "Bold Proposer Report" "$DEBATE_REPORT" && \
       grep -q "Critique Report" "$DEBATE_REPORT" && \
       grep -q "Reducer Report" "$DEBATE_REPORT"; then
        test_info "✓ Debate report contains all 3 agent reports"
    else
        test_fail "Debate report missing content from one or more reports"
    fi
else
    test_fail "Debate report file not created"
fi

# Test Case 5: Usage message documents 3-path requirement
test_info "Test 5: Usage message documents 3-path requirement"

if "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" 2>&1 | grep -q "<path-to-report1> <path-to-report2> <path-to-report3>"; then
    test_info "✓ Usage message documents 3-path requirement"
else
    test_fail "Usage message missing 3-path documentation"
fi

# Test Case 6: Feature name extraction from header format
test_info "Test 6: Extract feature name from header format"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

# Feature: Header Format Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Header Format Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from header format"
    else
        test_fail "Feature name not extracted from header format (expected 'Header Format Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for header format test"
fi

# Test Case 7: Feature name extraction from plain label format
test_info "Test 7: Extract feature name from plain label format"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

Feature: Plain Label Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Plain Label Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from plain label format"
    else
        test_fail "Feature name not extracted from plain label format (expected 'Plain Label Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for plain label test"
fi

# Test Case 8: Feature name extraction from "Title" label variant
test_info "Test 8: Extract feature name from Title label variant"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

**Title**: Title Variant Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Title Variant Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from Title label variant"
    else
        test_fail "Feature name not extracted from Title label (expected 'Title Variant Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for Title label test"
fi

# Cleanup
rm -f "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" "$DEBATE_REPORT"
pkill -9 -f "codex exec" 2>/dev/null || true

test_pass "All external-consensus argument parsing tests passed"
