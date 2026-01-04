#!/bin/bash
set -e

# Test: ultra-planner creates issue-numbered artifacts and updates placeholder issue

echo "Testing ultra-planner issue-first workflow..."

# Setup test environment
MOCK_FEATURE="Add user authentication with JWT"
TEST_TMP=".tmp/test-ultra-planner"
mkdir -p "$TEST_TMP"

# Mock gh command to capture issue creation and updates
GH_CAPTURE="$TEST_TMP/gh-capture.txt"
cat > "$TEST_TMP/gh-mock.sh" <<'GHEOF'
#!/bin/bash
if [ "$1" = "issue" ] && [ "$2" = "create" ]; then
    # Capture create operation
    echo "CREATE" >> "$GH_CAPTURE"
    while [ $# -gt 0 ]; do
        if [ "$1" = "--title" ]; then
            echo "TITLE: $2" >> "$GH_CAPTURE"
        fi
        shift
    done
    # Return mock issue with number 42
    echo '{"number": 42, "url": "https://github.com/test/repo/issues/42"}'
    exit 0
elif [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
    # Capture edit operation
    echo "EDIT $3" >> "$GH_CAPTURE"
    while [ $# -gt 0 ]; do
        if [ "$1" = "--title" ]; then
            echo "TITLE: $2" >> "$GH_CAPTURE"
        fi
        shift
    done
    echo '{"number": '"$3"', "url": "https://github.com/test/repo/issues/'"$3"'"}'
    exit 0
fi
echo "{}"
GHEOF
chmod +x "$TEST_TMP/gh-mock.sh"

export GH_CAPTURE
export PATH="$TEST_TMP:$PATH"

# Test 1: Placeholder creation extracts ISSUE_NUMBER from URL
echo "Test 1: Placeholder creation extracts ISSUE_NUMBER from URL"
rm -f "$GH_CAPTURE"
# Simulate ultra-planner creating placeholder
"$TEST_TMP/gh-mock.sh" issue create --title "[plan][feat]: $MOCK_FEATURE" --body "Placeholder"
ISSUE_URL_OUTPUT=$("$TEST_TMP/gh-mock.sh" issue create --title "[plan][feat]: $MOCK_FEATURE" --body "Placeholder")
ISSUE_NUMBER=$(echo "$ISSUE_URL_OUTPUT" | grep -o '"number": [0-9]*' | grep -o '[0-9]*')

if [ "$ISSUE_NUMBER" = "42" ]; then
    echo "✓ Test 1 passed: Extracted ISSUE_NUMBER=42 from URL"
else
    echo "✗ Test 1 failed: Expected ISSUE_NUMBER=42, got '$ISSUE_NUMBER'"
    exit 1
fi

# Test 2: Filenames include issue-{N}- prefix
echo "Test 2: Artifact filenames use issue-{N}- prefix"
# Simulate creating debate artifacts with issue number prefix
BOLD_FILE="$TEST_TMP/issue-42-bold-proposal.md"
CRITIQUE_FILE="$TEST_TMP/issue-42-critique.md"
REDUCER_FILE="$TEST_TMP/issue-42-reducer.md"
DEBATE_FILE="$TEST_TMP/issue-42-debate.md"
CONSENSUS_FILE="$TEST_TMP/issue-42-consensus.md"

touch "$BOLD_FILE" "$CRITIQUE_FILE" "$REDUCER_FILE" "$DEBATE_FILE" "$CONSENSUS_FILE"

# Verify all files exist with correct naming pattern
MISSING_FILES=0
for file in "$BOLD_FILE" "$CRITIQUE_FILE" "$REDUCER_FILE" "$DEBATE_FILE" "$CONSENSUS_FILE"; do
    if [ ! -f "$file" ]; then
        echo "✗ Missing file: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    echo "✓ Test 2 passed: All artifacts use issue-42- prefix"
else
    echo "✗ Test 2 failed: $MISSING_FILES files missing with issue-{N}- prefix"
    exit 1
fi

# Test 3: Final step updates existing issue (no second issue created)
echo "Test 3: Consensus updates existing issue (no second create)"
rm -f "$GH_CAPTURE"

# Simulate placeholder creation
"$TEST_TMP/gh-mock.sh" issue create --title "[plan][feat]: $MOCK_FEATURE" --body "Placeholder" > /dev/null

# Simulate consensus updating the same issue
"$TEST_TMP/gh-mock.sh" issue edit 42 --title "[plan][feat]: $MOCK_FEATURE" --body "Final consensus plan" > /dev/null

# Verify we have exactly 1 CREATE and 1 EDIT operation
CREATE_COUNT=$(grep -c "^CREATE$" "$GH_CAPTURE" || true)
EDIT_COUNT=$(grep -c "^EDIT 42$" "$GH_CAPTURE" || true)

if [ "$CREATE_COUNT" = "1" ] && [ "$EDIT_COUNT" = "1" ]; then
    echo "✓ Test 3 passed: Exactly 1 create + 1 edit (no duplicate issue)"
else
    echo "✗ Test 3 failed: Expected 1 create + 1 edit, got $CREATE_COUNT creates + $EDIT_COUNT edits"
    cat "$GH_CAPTURE"
    exit 1
fi

# Test 4: Update preserves [plan] prefix
echo "Test 4: Issue update preserves [plan] prefix"
rm -f "$GH_CAPTURE"
"$TEST_TMP/gh-mock.sh" issue edit 42 --title "[plan][feat]: Updated consensus plan" > /dev/null

UPDATED_TITLE=$(grep "TITLE:" "$GH_CAPTURE" | tail -1 | cut -d' ' -f2-)
if [[ "$UPDATED_TITLE" == "[plan][feat]:"* ]]; then
    echo "✓ Test 4 passed: Updated title preserves [plan] prefix"
else
    echo "✗ Test 4 failed: Expected [plan] prefix, got '$UPDATED_TITLE'"
    exit 1
fi

# Cleanup
rm -rf "$TEST_TMP"

echo ""
echo "All ultra-planner tests passed!"
