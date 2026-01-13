#!/usr/bin/env bash
# Test: Handsoff session path with AGENTIZE_HOME and issue_no extraction

source "$(dirname "$0")/../common.sh"

HOOK_SCRIPT="$PROJECT_ROOT/hooks/user-prompt-submit.py"

test_info "Handsoff session path and issue_no extraction tests"

# Create temporary directories for test isolation
TMP_DIR=$(make_temp_dir "handsoff-session-test")
CENTRAL_HOME="$TMP_DIR/central"
LOCAL_HOME="$TMP_DIR/local"
mkdir -p "$CENTRAL_HOME" "$LOCAL_HOME"

# Helper: Run user-prompt-submit hook with specified prompt and AGENTIZE_HOME
run_hook() {
    local prompt="$1"
    local session_id="$2"
    local agentize_home="${3:-}"  # Empty means unset

    local input=$(cat <<EOF
{"prompt": "$prompt", "session_id": "$session_id"}
EOF
)

    if [ -n "$agentize_home" ]; then
        HANDSOFF_MODE=1 AGENTIZE_HOME="$agentize_home" python3 "$HOOK_SCRIPT" <<< "$input"
    else
        # Run without AGENTIZE_HOME (in local directory context)
        (cd "$LOCAL_HOME" && unset AGENTIZE_HOME && HANDSOFF_MODE=1 python3 "$HOOK_SCRIPT" <<< "$input")
    fi
}

# Test 1: With AGENTIZE_HOME set, session file created in central location
test_info "Test 1: AGENTIZE_HOME set → central session file"
SESSION_ID_1="test-session-central-1"
run_hook "/issue-to-impl 42" "$SESSION_ID_1" "$CENTRAL_HOME"

STATE_FILE_1="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_1.json"
[ -f "$STATE_FILE_1" ] || test_fail "Session file not created at central path: $STATE_FILE_1"

# Verify issue_no is extracted
ISSUE_NO_1=$(jq -r '.issue_no' "$STATE_FILE_1")
[ "$ISSUE_NO_1" = "42" ] || test_fail "Expected issue_no=42, got '$ISSUE_NO_1'"

# Test 2: Without AGENTIZE_HOME, session file created in local .tmp/
test_info "Test 2: AGENTIZE_HOME unset → local session file"
SESSION_ID_2="test-session-local-2"
run_hook "/issue-to-impl 99" "$SESSION_ID_2" ""

STATE_FILE_2="$LOCAL_HOME/.tmp/hooked-sessions/$SESSION_ID_2.json"
[ -f "$STATE_FILE_2" ] || test_fail "Session file not created at local path: $STATE_FILE_2"

# Verify issue_no is extracted
ISSUE_NO_2=$(jq -r '.issue_no' "$STATE_FILE_2")
[ "$ISSUE_NO_2" = "99" ] || test_fail "Expected issue_no=99, got '$ISSUE_NO_2'"

# Test 3: /ultra-planner with --refine <issue> extracts issue_no
test_info "Test 3: /ultra-planner --refine 123 → issue_no=123"
SESSION_ID_3="test-session-refine-3"
run_hook "/ultra-planner --refine 123" "$SESSION_ID_3" "$CENTRAL_HOME"

STATE_FILE_3="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_3.json"
[ -f "$STATE_FILE_3" ] || test_fail "Session file not created: $STATE_FILE_3"

ISSUE_NO_3=$(jq -r '.issue_no' "$STATE_FILE_3")
[ "$ISSUE_NO_3" = "123" ] || test_fail "Expected issue_no=123, got '$ISSUE_NO_3'"

WORKFLOW_3=$(jq -r '.workflow' "$STATE_FILE_3")
[ "$WORKFLOW_3" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_3'"

# Test 4: /ultra-planner <feature> without issue number → issue_no absent
test_info "Test 4: /ultra-planner <feature> → issue_no absent"
SESSION_ID_4="test-session-noissue-4"
run_hook "/ultra-planner new feature idea" "$SESSION_ID_4" "$CENTRAL_HOME"

STATE_FILE_4="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_4.json"
[ -f "$STATE_FILE_4" ] || test_fail "Session file not created: $STATE_FILE_4"

ISSUE_NO_4=$(jq -r '.issue_no' "$STATE_FILE_4")
[ "$ISSUE_NO_4" = "null" ] || test_fail "Expected issue_no=null (absent), got '$ISSUE_NO_4'"

# Test 4b: /ultra-planner --from-issue 456 → issue_no=456
test_info "Test 4b: /ultra-planner --from-issue 456 → issue_no=456"
SESSION_ID_4b="test-session-from-issue-4b"
run_hook "/ultra-planner --from-issue 456" "$SESSION_ID_4b" "$CENTRAL_HOME"

STATE_FILE_4b="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_4b.json"
[ -f "$STATE_FILE_4b" ] || test_fail "Session file not created: $STATE_FILE_4b"

ISSUE_NO_4b=$(jq -r '.issue_no' "$STATE_FILE_4b")
[ "$ISSUE_NO_4b" = "456" ] || test_fail "Expected issue_no=456, got '$ISSUE_NO_4b'"

WORKFLOW_4b=$(jq -r '.workflow' "$STATE_FILE_4b")
[ "$WORKFLOW_4b" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_4b'"

# Test 5: Workflow field is correctly set
test_info "Test 5: workflow field set correctly for issue-to-impl"
WORKFLOW_1=$(jq -r '.workflow' "$STATE_FILE_1")
[ "$WORKFLOW_1" = "issue-to-impl" ] || test_fail "Expected workflow=issue-to-impl, got '$WORKFLOW_1'"

# Test 6: continuation_count starts at 0
test_info "Test 6: continuation_count starts at 0"
COUNT_1=$(jq -r '.continuation_count' "$STATE_FILE_1")
[ "$COUNT_1" = "0" ] || test_fail "Expected continuation_count=0, got '$COUNT_1'"

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "Handsoff session path and issue_no extraction works correctly"
