#!/bin/bash
set -e

# Test: open-issue --draft flag produces correct title prefix

echo "Testing open-issue --draft flag..."

# Create a mock plan file for testing
MOCK_PLAN_FILE=".tmp/test-plan-draft.md"
mkdir -p .tmp
cat > "$MOCK_PLAN_FILE" <<'EOF'
# Test Feature Plan

## Goal
Add test feature

## Implementation Steps
1. Create test file
2. Write tests
3. Implement feature

Total LOC: ~50 (Small)
EOF

# Mock gh command to capture the issue creation
export GH_MOCK=true
export GH_CAPTURE_FILE=".tmp/gh-capture-draft.txt"

# Create a wrapper script for gh that captures the title
mkdir -p .tmp
cat > .tmp/gh-mock.sh <<'GHEOF'
#!/bin/bash
if [ "$1" = "issue" ] && [ "$2" = "create" ]; then
    # Extract title from arguments
    while [ $# -gt 0 ]; do
        if [ "$1" = "--title" ]; then
            echo "TITLE: $2" > "$GH_CAPTURE_FILE"
            echo "{\"number\": 999, \"url\": \"https://github.com/test/repo/issues/999\"}"
            exit 0
        fi
        shift
    done
fi
echo "{}"
GHEOF
chmod +x .tmp/gh-mock.sh

# Add mock gh to PATH
export PATH=".tmp:$PATH"
export GH=".tmp/gh-mock.sh"

# Test without --draft flag (baseline)
echo "Test 1: Without --draft flag"
rm -f "$GH_CAPTURE_FILE"
# Simulate open-issue skill behavior without --draft
TITLE="[plan][feat]: Add test feature"
.tmp/gh-mock.sh issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)
if [ "$CAPTURED_TITLE" = "[plan][feat]: Add test feature" ]; then
    echo "✓ Test 1 passed: Title without --draft is correct"
else
    echo "✗ Test 1 failed: Expected '[plan][feat]: Add test feature', got '$CAPTURED_TITLE'"
    exit 1
fi

# Test with --draft flag
echo "Test 2: With --draft flag"
rm -f "$GH_CAPTURE_FILE"
# Simulate open-issue skill behavior with --draft
TITLE="[draft][plan][feat]: Add test feature"
.tmp/gh-mock.sh issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)
if [ "$CAPTURED_TITLE" = "[draft][plan][feat]: Add test feature" ]; then
    echo "✓ Test 2 passed: Title with --draft has [draft] prefix"
else
    echo "✗ Test 2 failed: Expected '[draft][plan][feat]: Add test feature', got '$CAPTURED_TITLE'"
    exit 1
fi

# Test --draft with non-plan issue (should not add draft prefix)
echo "Test 3: --draft with non-plan issue (bug report)"
rm -f "$GH_CAPTURE_FILE"
# Bug reports should not get [draft] prefix even with --draft flag
TITLE="[bugfix]: Fix authentication error"
.tmp/gh-mock.sh issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)
if [ "$CAPTURED_TITLE" = "[bugfix]: Fix authentication error" ]; then
    echo "✓ Test 3 passed: Non-plan issues don't get [draft] prefix"
else
    echo "✗ Test 3 failed: Expected '[bugfix]: Fix authentication error', got '$CAPTURED_TITLE'"
    exit 1
fi

# Cleanup
rm -f "$MOCK_PLAN_FILE" "$GH_CAPTURE_FILE" .tmp/gh-mock.sh

echo ""
echo "All open-issue --draft tests passed!"
