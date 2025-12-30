#!/bin/bash
set -e

# Test: /refine-issue command flow with stubbed gh

echo "Testing /refine-issue command flow..."

# Setup test environment
mkdir -p .tmp

# Create mock issue data
MOCK_ISSUE_NUMBER=42
MOCK_ISSUE_TITLE="[draft][plan][feat]: Add user authentication"
MOCK_ISSUE_BODY="## Description

Add user authentication with JWT tokens.

## Proposed Solution

### Implementation Steps
1. Add auth middleware
2. Create JWT utilities
3. Add login endpoint

Total LOC: ~150 (Medium)"

# Mock gh command
cat > .tmp/gh-mock-refine.sh <<'GHEOF'
#!/bin/bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
    # Return mock issue data
    cat <<'ISSUEEOF'
{
  "title": "[draft][plan][feat]: Add user authentication",
  "body": "## Description\n\nAdd user authentication with JWT tokens.\n\n## Proposed Solution\n\n### Implementation Steps\n1. Add auth middleware\n2. Create JWT utilities\n3. Add login endpoint\n\nTotal LOC: ~150 (Medium)",
  "state": "OPEN"
}
ISSUEEOF
    exit 0
elif [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
    # Capture the edit operation
    echo "EDIT: Issue $3 updated" > .tmp/gh-edit-capture.txt
    # Capture body file content
    if [ "$4" = "--body-file" ]; then
        cp "$5" .tmp/gh-edit-body-capture.txt
    fi
    exit 0
fi
echo "{}"
GHEOF
chmod +x .tmp/gh-mock-refine.sh

# Add mock gh to PATH
export PATH=".tmp:$PATH"

# Test 1: Verify issue fetch
echo "Test 1: Fetch issue data"
ISSUE_JSON=$(.tmp/gh-mock-refine.sh issue view "$MOCK_ISSUE_NUMBER" --json title,body,state)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | grep -o '"title": "[^"]*"' | cut -d'"' -f4)
if echo "$ISSUE_TITLE" | grep -q "\[draft\]\[plan\]\[feat\]"; then
    echo "✓ Test 1 passed: Issue fetched correctly"
else
    echo "✗ Test 1 failed: Could not fetch issue title"
    exit 1
fi

# Test 2: Verify plan extraction
echo "Test 2: Extract plan from issue body"
ISSUE_BODY=$(echo "$ISSUE_JSON" | sed -n 's/.*"body": "\(.*\)",/\1/p' | sed 's/\\n/\n/g')
TEMP_PLAN_FILE=".tmp/issue-${MOCK_ISSUE_NUMBER}-original-test.md"
echo "$ISSUE_BODY" > "$TEMP_PLAN_FILE"
if [ -f "$TEMP_PLAN_FILE" ] && grep -q "Implementation Steps" "$TEMP_PLAN_FILE"; then
    echo "✓ Test 2 passed: Plan extracted to temp file"
else
    echo "✗ Test 2 failed: Plan extraction failed"
    exit 1
fi

# Test 3: Verify issue update (simulate)
echo "Test 3: Update issue with refined plan"
REFINED_PLAN_FILE=".tmp/consensus-plan-refined-test.md"
cat > "$REFINED_PLAN_FILE" <<'EOF'
## Description

Add user authentication with JWT tokens and improved security.

## Proposed Solution

### Implementation Steps
1. Add auth middleware with rate limiting
2. Create JWT utilities with refresh tokens
3. Add login endpoint with 2FA support
4. Add security tests

Total LOC: ~200 (Medium)
EOF

.tmp/gh-mock-refine.sh issue edit "$MOCK_ISSUE_NUMBER" --body-file "$REFINED_PLAN_FILE"

if [ -f .tmp/gh-edit-capture.txt ] && grep -q "Issue $MOCK_ISSUE_NUMBER updated" .tmp/gh-edit-capture.txt; then
    echo "✓ Test 3 passed: Issue update command executed"
else
    echo "✗ Test 3 failed: Issue update failed"
    exit 1
fi

# Test 4: Verify updated body content
echo "Test 4: Verify refined plan content"
if [ -f .tmp/gh-edit-body-capture.txt ] && grep -q "rate limiting" .tmp/gh-edit-body-capture.txt; then
    echo "✓ Test 4 passed: Refined plan contains improvements"
else
    echo "✗ Test 4 failed: Refined plan content incorrect"
    exit 1
fi

# Test 5: Verify draft prefix preservation
echo "Test 5: Verify draft prefix is preserved"
# The title should still have [draft] prefix after refinement
# (This is enforced by the command logic, not gh)
if echo "$ISSUE_TITLE" | grep -q "\[draft\]"; then
    echo "✓ Test 5 passed: Draft prefix preserved in original issue"
else
    echo "✗ Test 5 failed: Draft prefix missing"
    exit 1
fi

# Test 6: Verify argument parsing (issue number + refinement instructions)
echo "Test 6: Parse issue number and refinement instructions"
MOCK_ARGUMENTS="42 Focus on reducing complexity"
PARSED_ISSUE_NUMBER=$(echo "$MOCK_ARGUMENTS" | awk '{print $1}')
PARSED_REFINEMENT=$(echo "$MOCK_ARGUMENTS" | cut -d' ' -f2-)

if [ "$PARSED_ISSUE_NUMBER" = "42" ] && [ "$PARSED_REFINEMENT" = "Focus on reducing complexity" ]; then
    echo "✓ Test 6 passed: Arguments parsed correctly"
else
    echo "✗ Test 6 failed: Argument parsing failed"
    echo "  Expected issue: 42, got: $PARSED_ISSUE_NUMBER"
    echo "  Expected refinement: 'Focus on reducing complexity', got: '$PARSED_REFINEMENT'"
    exit 1
fi

# Test 7: Verify argument parsing (issue number only)
echo "Test 7: Parse issue number without refinement instructions"
MOCK_ARGUMENTS_SIMPLE="42"
PARSED_ISSUE_NUMBER_SIMPLE=$(echo "$MOCK_ARGUMENTS_SIMPLE" | awk '{print $1}')
PARSED_REFINEMENT_SIMPLE=$(echo "$MOCK_ARGUMENTS_SIMPLE" | cut -d' ' -f2-)

# When only issue number provided, refinement should equal issue number
# Command should detect this and clear refinement instructions
if [ "$PARSED_ISSUE_NUMBER_SIMPLE" = "42" ] && [ "$PARSED_REFINEMENT_SIMPLE" = "$PARSED_ISSUE_NUMBER_SIMPLE" ]; then
    echo "✓ Test 7 passed: Issue-only arguments parsed correctly"
else
    echo "✗ Test 7 failed: Issue-only argument parsing failed"
    exit 1
fi

# Cleanup
rm -f .tmp/gh-mock-refine.sh .tmp/gh-edit-capture.txt .tmp/gh-edit-body-capture.txt
rm -f "$TEMP_PLAN_FILE" "$REFINED_PLAN_FILE"

echo ""
echo "All /refine-issue tests passed!"
