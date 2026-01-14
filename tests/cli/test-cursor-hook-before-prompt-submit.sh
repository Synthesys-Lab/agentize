#!/usr/bin/env bash
# Test: Cursor beforePromptSubmit hook functionality

source "$(dirname "$0")/../common.sh"

HOOK_SCRIPT="$PROJECT_ROOT/.cursor/hooks/before-prompt-submit.py"

test_info "Cursor beforePromptSubmit hook tests"

# Create temporary directories for test isolation
TMP_DIR=$(make_temp_dir "cursor-hook-test")
CENTRAL_HOME="$TMP_DIR/central"
LOCAL_HOME="$TMP_DIR/local"
mkdir -p "$CENTRAL_HOME" "$LOCAL_HOME"

# Helper: Run before-prompt-submit hook with specified prompt and AGENTIZE_HOME
run_hook() {
    local prompt="$1"
    local session_id="$2"
    local agentize_home="${3:-}"  # Empty means unset
    local handsoff_mode="${4:-1}"  # Default to enabled

    local input=$(cat <<EOF
{"prompt": "$prompt", "session_id": "$session_id"}
EOF
)

    if [ -n "$agentize_home" ]; then
        HANDSOFF_MODE="$handsoff_mode" AGENTIZE_HOME="$agentize_home" python3 "$HOOK_SCRIPT" <<< "$input"
    else
        # Run without AGENTIZE_HOME (in local directory context)
        (cd "$LOCAL_HOME" && unset AGENTIZE_HOME && HANDSOFF_MODE="$handsoff_mode" python3 "$HOOK_SCRIPT" <<< "$input")
    fi
}

# Test 1: Hook exits early when HANDSOFF_MODE=0
test_info "Test 1: HANDSOFF_MODE=0 → hook exits early"
SESSION_ID_1="test-session-disabled-1"
run_hook "/issue-to-impl 42" "$SESSION_ID_1" "$CENTRAL_HOME" "0"

STATE_FILE_1="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_1.json"
[ ! -f "$STATE_FILE_1" ] || test_fail "Session file should not be created when HANDSOFF_MODE=0: $STATE_FILE_1"

# Test 2: With AGENTIZE_HOME set, session file created in central location
test_info "Test 2: AGENTIZE_HOME set → central session file"
SESSION_ID_2="test-session-central-2"
run_hook "/issue-to-impl 42" "$SESSION_ID_2" "$CENTRAL_HOME"

STATE_FILE_2="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_2.json"
[ -f "$STATE_FILE_2" ] || test_fail "Session file not created at central path: $STATE_FILE_2"

# Verify issue_no is extracted
ISSUE_NO_2=$(jq -r '.issue_no' "$STATE_FILE_2")
[ "$ISSUE_NO_2" = "42" ] || test_fail "Expected issue_no=42, got '$ISSUE_NO_2'"

# Test 3: Without AGENTIZE_HOME, session file created in local .tmp/
test_info "Test 3: AGENTIZE_HOME unset → local session file"
SESSION_ID_3="test-session-local-3"
run_hook "/issue-to-impl 99" "$SESSION_ID_3" ""

STATE_FILE_3="$LOCAL_HOME/.tmp/hooked-sessions/$SESSION_ID_3.json"
[ -f "$STATE_FILE_3" ] || test_fail "Session file not created at local path: $STATE_FILE_3"

# Verify issue_no is extracted
ISSUE_NO_3=$(jq -r '.issue_no' "$STATE_FILE_3")
[ "$ISSUE_NO_3" = "99" ] || test_fail "Expected issue_no=99, got '$ISSUE_NO_3'"

# Test 4: /ultra-planner with --refine <issue> extracts issue_no
test_info "Test 4: /ultra-planner --refine 123 → issue_no=123"
SESSION_ID_4="test-session-refine-4"
run_hook "/ultra-planner --refine 123" "$SESSION_ID_4" "$CENTRAL_HOME"

STATE_FILE_4="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_4.json"
[ -f "$STATE_FILE_4" ] || test_fail "Session file not created: $STATE_FILE_4"

ISSUE_NO_4=$(jq -r '.issue_no' "$STATE_FILE_4")
[ "$ISSUE_NO_4" = "123" ] || test_fail "Expected issue_no=123, got '$ISSUE_NO_4'"

WORKFLOW_4=$(jq -r '.workflow' "$STATE_FILE_4")
[ "$WORKFLOW_4" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_4'"

# Test 5: /ultra-planner <feature> without issue number → issue_no absent
test_info "Test 5: /ultra-planner <feature> → issue_no absent"
SESSION_ID_5="test-session-noissue-5"
run_hook "/ultra-planner new feature idea" "$SESSION_ID_5" "$CENTRAL_HOME"

STATE_FILE_5="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_5.json"
[ -f "$STATE_FILE_5" ] || test_fail "Session file not created: $STATE_FILE_5"

ISSUE_NO_5=$(jq -r '.issue_no' "$STATE_FILE_5")
[ "$ISSUE_NO_5" = "null" ] || test_fail "Expected issue_no=null (absent), got '$ISSUE_NO_5'"

# Test 6: /ultra-planner --from-issue 456 → issue_no=456
test_info "Test 6: /ultra-planner --from-issue 456 → issue_no=456"
SESSION_ID_6="test-session-from-issue-6"
run_hook "/ultra-planner --from-issue 456" "$SESSION_ID_6" "$CENTRAL_HOME"

STATE_FILE_6="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_6.json"
[ -f "$STATE_FILE_6" ] || test_fail "Session file not created: $STATE_FILE_6"

ISSUE_NO_6=$(jq -r '.issue_no' "$STATE_FILE_6")
[ "$ISSUE_NO_6" = "456" ] || test_fail "Expected issue_no=456, got '$ISSUE_NO_6'"

WORKFLOW_6=$(jq -r '.workflow' "$STATE_FILE_6")
[ "$WORKFLOW_6" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_6'"

# Test 7: Workflow field is correctly set for issue-to-impl
test_info "Test 7: workflow field set correctly for issue-to-impl"
WORKFLOW_2=$(jq -r '.workflow' "$STATE_FILE_2")
[ "$WORKFLOW_2" = "issue-to-impl" ] || test_fail "Expected workflow=issue-to-impl, got '$WORKFLOW_2'"

# Test 8: continuation_count starts at 0
test_info "Test 8: continuation_count starts at 0"
COUNT_2=$(jq -r '.continuation_count' "$STATE_FILE_2")
[ "$COUNT_2" = "0" ] || test_fail "Expected continuation_count=0, got '$COUNT_2'"

# Test 9: Issue index file created when issue_no is present
test_info "Test 9: Issue index file created when issue_no present"
ISSUE_INDEX_FILE_2="$CENTRAL_HOME/.tmp/hooked-sessions/by-issue/42.json"
[ -f "$ISSUE_INDEX_FILE_2" ] || test_fail "Issue index file not created: $ISSUE_INDEX_FILE_2"

INDEX_SESSION_ID=$(jq -r '.session_id' "$ISSUE_INDEX_FILE_2")
[ "$INDEX_SESSION_ID" = "$SESSION_ID_2" ] || test_fail "Expected session_id=$SESSION_ID_2 in index, got '$INDEX_SESSION_ID'"

INDEX_WORKFLOW=$(jq -r '.workflow' "$ISSUE_INDEX_FILE_2")
[ "$INDEX_WORKFLOW" = "issue-to-impl" ] || test_fail "Expected workflow=issue-to-impl in index, got '$INDEX_WORKFLOW'"

# Test 10: Issue index file NOT created when issue_no is absent
test_info "Test 10: Issue index file NOT created when issue_no absent"
ISSUE_INDEX_FILE_5="$CENTRAL_HOME/.tmp/hooked-sessions/by-issue/null.json"
[ ! -f "$ISSUE_INDEX_FILE_5" ] || test_fail "Issue index file should not be created when issue_no is absent"

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "Cursor beforePromptSubmit hook works correctly"
