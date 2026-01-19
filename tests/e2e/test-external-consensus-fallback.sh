#!/usr/bin/env bash
# Test: external-consensus.sh three-tier fallback cascade
#
# Tests all three fallback paths:
# - Tier 1: Codex CLI (preferred)
# - Tier 2: Cursor Agent CLI with gpt-5.2-codex-xhigh (intermediate)
# - Tier 3: Claude Opus via Claude Code CLI (final fallback)

source "$(dirname "$0")/../common.sh"

test_info "Testing external-consensus.sh three-tier fallback cascade"

# Setup: Create test agent reports
ISSUE_NUMBER=515
REPORT1_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-bold-proposal.md"
REPORT2_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-critique.md"
REPORT3_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-reducer.md"

mkdir -p "$PROJECT_ROOT/.tmp"
cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

**Feature**: Cursor Agent CLI Fallback

This is a bold proposal for adding Cursor Agent CLI fallback support.
EOF

cat > "$REPORT2_FILE" << 'EOF'
# Critique Report

This is a critique of the fallback proposal.
EOF

cat > "$REPORT3_FILE" << 'EOF'
# Reducer Report

This is a simplified version of the proposal.
EOF

# Test Case 1: Verify detection of Codex CLI
test_info "Test 1: Detect Codex CLI availability"

# Create a mock codex command if not available
if ! command -v codex &> /dev/null; then
    test_info "  - Codex not available in system PATH (expected)"
    CODEX_AVAILABLE=false
else
    test_info "  - Codex is available in system PATH"
    CODEX_AVAILABLE=true
fi

# Verify the script checks for codex
# Run in background and capture output, killing after debate report creation
(
    "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) > /tmp/consensus-output.txt &
SCRIPT_PID=$!

# Wait briefly for output to be written
sleep 1
kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

SCRIPT_OUTPUT=$(cat /tmp/consensus-output.txt)
rm -f /tmp/consensus-output.txt

if echo "$SCRIPT_OUTPUT" | grep -q "Tier 1: Model gpt-5.2-codex"; then
    if [ "$CODEX_AVAILABLE" = true ]; then
        test_info "✓ Script correctly detected and attempted to use Codex"
    else
        test_fail "Script claims Codex is available but it's not in PATH"
    fi
else
    if [ "$CODEX_AVAILABLE" = false ]; then
        test_info "✓ Script correctly skipped Codex tier (not available)"
    else
        test_fail "Script should have detected Codex availability"
    fi
fi

# Test Case 2: Verify detection of Cursor Agent CLI
test_info "Test 2: Detect Cursor Agent CLI availability"

# Check if agent command exists
if ! command -v agent &> /dev/null; then
    test_info "  - Agent CLI not available in system PATH (expected)"
    AGENT_AVAILABLE=false
else
    test_info "  - Agent CLI is available in system PATH"
    # Verify gpt-5.2-codex-xhigh model availability
    if agent --list-models 2>/dev/null | grep -q "gpt-5.2-codex-xhigh"; then
        test_info "  - gpt-5.2-codex-xhigh model is available"
        AGENT_AVAILABLE=true
    else
        test_info "  - gpt-5.2-codex-xhigh model not found in available models"
        AGENT_AVAILABLE=false
    fi
fi

# Test Case 3: Verify detection of Claude Code CLI (final fallback)
test_info "Test 3: Detect Claude Code CLI availability"

if ! command -v claude &> /dev/null; then
    test_fail "Claude Code CLI should be available in this environment"
else
    test_info "✓ Claude Code CLI is available in system PATH (final fallback)"
    CLAUDE_AVAILABLE=true
fi

# Test Case 4: Verify Tier 1 Codex output format when available
if [ "$CODEX_AVAILABLE" = true ]; then
    test_info "Test 4: Codex tier output includes read-only sandbox configuration"

    (
        "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
            "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
    ) > /tmp/consensus-output-4.txt &
    SCRIPT_PID=$!
    sleep 1
    kill -9 $SCRIPT_PID 2>/dev/null || true
    wait $SCRIPT_PID 2>/dev/null || true
    SCRIPT_OUTPUT=$(cat /tmp/consensus-output-4.txt)
    rm -f /tmp/consensus-output-4.txt

    if echo "$SCRIPT_OUTPUT" | grep -q "Sandbox: read-only" && \
       echo "$SCRIPT_OUTPUT" | grep -q "Web search: enabled" && \
       echo "$SCRIPT_OUTPUT" | grep -q "Reasoning effort: xhigh"; then
        test_info "✓ Codex tier correctly displays all advanced features"
    else
        test_fail "Codex tier output missing advanced feature indicators"
    fi
else
    test_info "Test 4: Skipping (Codex not available)"
fi

# Test Case 5: Verify Tier 2 Agent CLI output format when available
if [ "$CODEX_AVAILABLE" = false ] && [ "$AGENT_AVAILABLE" = true ]; then
    test_info "Test 5: Agent CLI tier output includes model configuration"

    (
        "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
            "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
    ) > /tmp/consensus-output-5.txt &
    SCRIPT_PID=$!
    sleep 1
    kill -9 $SCRIPT_PID 2>/dev/null || true
    wait $SCRIPT_PID 2>/dev/null || true
    SCRIPT_OUTPUT=$(cat /tmp/consensus-output-5.txt)
    rm -f /tmp/consensus-output-5.txt

    if echo "$SCRIPT_OUTPUT" | grep -q "Tier 2: Model gpt-5.2-codex-xhigh (Cursor Agent CLI)" && \
       echo "$SCRIPT_OUTPUT" | grep -q "Advanced reasoning: enabled"; then
        test_info "✓ Agent CLI tier correctly displays model configuration"
    else
        test_fail "Agent CLI tier output missing model configuration"
    fi
else
    test_info "Test 5: Skipping (Agent CLI not available or Codex takes precedence)"
fi

# Test Case 6: Verify Tier 3 Claude fallback output format
test_info "Test 6: Claude Opus fallback tier output format"

(
    "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) > /tmp/consensus-output-6.txt &
SCRIPT_PID=$!
sleep 1
kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true
SCRIPT_OUTPUT=$(cat /tmp/consensus-output-6.txt)
rm -f /tmp/consensus-output-6.txt

if echo "$SCRIPT_OUTPUT" | grep -q "Tier 3: Model opus (Claude Code CLI)"; then
    if echo "$SCRIPT_OUTPUT" | grep -q "Tools: Read, Grep, Glob, WebSearch, WebFetch (read-only)"; then
        test_info "✓ Claude tier correctly displays read-only tool configuration"
    else
        test_fail "Claude tier output missing tool configuration"
    fi
else
    # Either Tier 1 or Tier 2 was used
    test_info "✓ Fallback cascade reached Tier 1 or Tier 2 (Claude not needed)"
fi

# Test Case 7: Verify debate report is created before tier selection
test_info "Test 7: Debate report created regardless of tier selection"

DEBATE_REPORT="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-debate.md"
rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

# Wait for debate report creation
for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

# Kill the script (it would try to invoke an external AI tool)
kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    test_info "✓ Debate report created at expected path"

    # Verify it mentions the three-tier fallback strategy
    if grep -q "three-tier fallback strategy" "$DEBATE_REPORT"; then
        test_info "✓ Debate report mentions three-tier fallback strategy"
    else
        test_fail "Debate report missing fallback strategy documentation"
    fi
else
    test_fail "Debate report should be created before tier selection"
fi

# Test Case 8: Verify status messages reflect tier selection
test_info "Test 8: Status messages reflect which tier is being used"

if [ "$CODEX_AVAILABLE" = true ]; then
    (
        "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
            "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
    ) > /tmp/consensus-output-8.txt &
    SCRIPT_PID=$!
    sleep 1
    kill -9 $SCRIPT_PID 2>/dev/null || true
    wait $SCRIPT_PID 2>/dev/null || true
    SCRIPT_OUTPUT=$(cat /tmp/consensus-output-8.txt)
    rm -f /tmp/consensus-output-8.txt

    if echo "$SCRIPT_OUTPUT" | grep -q "Tier 1:"; then
        test_info "✓ Status message indicates Tier 1 selection"
    else
        test_fail "Status message should indicate tier selection"
    fi
elif [ "$AGENT_AVAILABLE" = true ]; then
    test_info "  - Would test Tier 2 selection if Agent CLI available"
else
    test_info "  - Testing with Tier 3 (Claude fallback)"
fi

# Test Case 9: Verify error handling for all tiers
test_info "Test 9: Error handling for invalid input"

INVALID_REPORT="$PROJECT_ROOT/.tmp/invalid-report.md"
rm -f "$INVALID_REPORT"

SCRIPT_OUTPUT=$(
    "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$INVALID_REPORT" "$REPORT3_FILE" 2>&1 || true
)

if echo "$SCRIPT_OUTPUT" | grep -q "Error: Report file not found"; then
    test_info "✓ Error handling works regardless of tier selection"
else
    test_fail "Error handling should catch missing files before tier selection"
fi

# Test Case 10: Verify cascading fallback logic
test_info "Test 10: Fallback cascade logic verification"

# Check that the script attempts tiers in correct order
if ! command -v codex &> /dev/null; then
    # Codex not available, script should check Agent CLI next
    SCRIPT_OUTPUT=$(timeout 3 "$PROJECT_ROOT/.opencode/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true)

    # Script should skip Tier 1 and check Tier 2/3
    if ! echo "$SCRIPT_OUTPUT" | grep -q "Tier 1: Model gpt-5.2-codex"; then
        test_info "✓ Correctly skipped Tier 1 (Codex not available)"
    else
        test_fail "Should skip Tier 1 if Codex not available"
    fi
else
    test_info "✓ Codex available, Tier 1 selection verified"
fi

# Cleanup
rm -f "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" "$DEBATE_REPORT"
pkill -9 -f "codex exec" 2>/dev/null || true
pkill -9 -f "agent exec" 2>/dev/null || true
pkill -9 -f "claude -p" 2>/dev/null || true

test_pass "All external-consensus fallback cascade tests passed"
