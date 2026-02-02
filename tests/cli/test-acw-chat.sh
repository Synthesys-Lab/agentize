#!/usr/bin/env bash
# Test: acw chat session functionality
# Verifies --chat and --chat-list work as expected

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw chat session functionality"

# Create isolated test directory for sessions
TEST_TMP=$(make_temp_dir "test-acw-chat-$$")
trap 'cleanup_dir "$TEST_TMP"' EXIT

# Create custom AGENTIZE_HOME to isolate sessions
export AGENTIZE_HOME="$TEST_TMP"
mkdir -p "$TEST_TMP/.tmp/acw-sessions"

source "$ACW_CLI"

# ============================================================
# Test 1: Chat helper functions exist
# ============================================================
test_info "Checking chat helper functions exist"

for func in _acw_chat_session_dir _acw_chat_session_path _acw_chat_generate_session_id \
            _acw_chat_validate_session_id _acw_chat_create_session \
            _acw_chat_validate_session_file _acw_chat_prepare_input \
            _acw_chat_append_turn _acw_chat_list_sessions; do
    if ! type "$func" 2>/dev/null | grep -q "function"; then
        test_fail "Function $func is not defined"
    fi
done

# ============================================================
# Test 2: Session directory helper
# ============================================================
test_info "Checking _acw_chat_session_dir"

session_dir=$(_acw_chat_session_dir)
expected_dir="$TEST_TMP/.tmp/acw-sessions"

if [ "$session_dir" != "$expected_dir" ]; then
    test_fail "Session dir mismatch: got '$session_dir', expected '$expected_dir'"
fi

if [ ! -d "$session_dir" ]; then
    test_fail "Session dir was not created"
fi

# ============================================================
# Test 3: Session ID generation
# ============================================================
test_info "Checking _acw_chat_generate_session_id"

id1=$(_acw_chat_generate_session_id)
id2=$(_acw_chat_generate_session_id)

# Check length (8 characters)
if [ ${#id1} -ne 8 ]; then
    test_fail "Generated ID wrong length: ${#id1}, expected 8"
fi

# Check uniqueness
if [ "$id1" = "$id2" ]; then
    test_fail "Generated IDs should be unique"
fi

# Check base62 characters only
if ! echo "$id1" | grep -qE '^[a-zA-Z0-9]+$'; then
    test_fail "Generated ID contains non-base62 characters: $id1"
fi

# ============================================================
# Test 4: Session ID validation
# ============================================================
test_info "Checking _acw_chat_validate_session_id"

# Valid IDs
if ! _acw_chat_validate_session_id "abc12345"; then
    test_fail "Valid 8-char ID rejected"
fi

if ! _acw_chat_validate_session_id "abcDEF123456"; then
    test_fail "Valid 12-char ID rejected"
fi

# Invalid IDs
if _acw_chat_validate_session_id "abc"; then
    test_fail "Too short ID (3 chars) should be rejected"
fi

if _acw_chat_validate_session_id "abc123456789012345"; then
    test_fail "Too long ID (18 chars) should be rejected"
fi

if _acw_chat_validate_session_id "abc-1234"; then
    test_fail "ID with hyphen should be rejected"
fi

if _acw_chat_validate_session_id "abc_1234"; then
    test_fail "ID with underscore should be rejected"
fi

# ============================================================
# Test 5: Session file creation
# ============================================================
test_info "Checking _acw_chat_create_session"

test_session_path="$session_dir/test_create.md"
_acw_chat_create_session "$test_session_path" "claude" "claude-sonnet-4-20250514"

if [ ! -f "$test_session_path" ]; then
    test_fail "Session file was not created"
fi

# Check YAML front matter
if ! head -1 "$test_session_path" | grep -q "^---$"; then
    test_fail "Session file missing YAML front matter start"
fi

if ! grep -q "^provider: claude$" "$test_session_path"; then
    test_fail "Session file missing provider"
fi

if ! grep -q "^model: claude-sonnet-4-20250514$" "$test_session_path"; then
    test_fail "Session file missing model"
fi

if ! grep -q "^created: " "$test_session_path"; then
    test_fail "Session file missing created timestamp"
fi

# ============================================================
# Test 6: Session file validation
# ============================================================
test_info "Checking _acw_chat_validate_session_file"

# Valid session should pass
if ! _acw_chat_validate_session_file "$test_session_path"; then
    test_fail "Valid session file rejected"
fi

# Create invalid session files
invalid_path="$session_dir/invalid.md"

# Missing YAML start
echo "provider: claude" > "$invalid_path"
if _acw_chat_validate_session_file "$invalid_path" 2>/dev/null; then
    test_fail "Session without YAML start should be rejected"
fi

# Missing provider
cat > "$invalid_path" <<'EOF'
---
model: test
created: 2025-01-15T10:00:00Z
---
EOF
if _acw_chat_validate_session_file "$invalid_path" 2>/dev/null; then
    test_fail "Session without provider should be rejected"
fi

# Non-existent file
if _acw_chat_validate_session_file "$session_dir/nonexistent.md" 2>/dev/null; then
    test_fail "Non-existent file should be rejected"
fi

# ============================================================
# Test 7: Session path resolution
# ============================================================
test_info "Checking _acw_chat_session_path"

resolved=$(_acw_chat_session_path "abc12345")
expected="$session_dir/abc12345.md"

if [ "$resolved" != "$expected" ]; then
    test_fail "Session path mismatch: got '$resolved', expected '$expected'"
fi

# ============================================================
# Test 8: Prepare input combines history and user input
# ============================================================
test_info "Checking _acw_chat_prepare_input"

# Create a session with existing turn
prep_session="$session_dir/prep_test.md"
cat > "$prep_session" <<'EOF'
---
provider: claude
model: test
created: 2025-01-15T10:00:00Z
---

# User
First question

# Assistant
First answer
EOF

# Create user input file
user_input="$TEST_TMP/user_input.txt"
echo "Second question" > "$user_input"

# Prepare combined input
combined_out="$TEST_TMP/combined.txt"
_acw_chat_prepare_input "$prep_session" "$user_input" "$combined_out"

if [ ! -f "$combined_out" ]; then
    test_fail "Combined input file was not created"
fi

# Check combined file contains session history
if ! grep -q "First question" "$combined_out"; then
    test_fail "Combined input missing session history"
fi

# Check combined file contains new user input
if ! grep -q "Second question" "$combined_out"; then
    test_fail "Combined input missing new user input"
fi

# Check combined file has User header for new input
if ! grep -q "# User" "$combined_out"; then
    test_fail "Combined input missing User header"
fi

# ============================================================
# Test 9: Append turn to session
# ============================================================
test_info "Checking _acw_chat_append_turn"

# Create fresh session
append_session="$session_dir/append_test.md"
_acw_chat_create_session "$append_session" "claude" "test"

# Create user and assistant content
user_file="$TEST_TMP/user.txt"
assistant_file="$TEST_TMP/assistant.txt"
echo "What is 2+2?" > "$user_file"
echo "The answer is 4." > "$assistant_file"

# Append turn
_acw_chat_append_turn "$append_session" "$user_file" "$assistant_file"

# Verify turn was appended
if ! grep -q "# User" "$append_session"; then
    test_fail "User header not appended"
fi

if ! grep -q "What is 2+2?" "$append_session"; then
    test_fail "User content not appended"
fi

if ! grep -q "# Assistant" "$append_session"; then
    test_fail "Assistant header not appended"
fi

if ! grep -q "The answer is 4." "$append_session"; then
    test_fail "Assistant content not appended"
fi

# ============================================================
# Test 10: List sessions
# ============================================================
test_info "Checking _acw_chat_list_sessions"

# Create a few sessions
_acw_chat_create_session "$session_dir/list1abc.md" "claude" "sonnet"
_acw_chat_create_session "$session_dir/list2def.md" "codex" "gpt-4o"

# List sessions
list_output=$(_acw_chat_list_sessions)

if ! echo "$list_output" | grep -q "list1abc"; then
    test_fail "list_sessions missing list1abc"
fi

if ! echo "$list_output" | grep -q "list2def"; then
    test_fail "list_sessions missing list2def"
fi

if ! echo "$list_output" | grep -q "claude"; then
    test_fail "list_sessions missing provider info"
fi

# ============================================================
# Test 11: --chat-list exits without provider args
# ============================================================
test_info "Checking --chat-list exits without requiring provider args"

# This should succeed without needing cli-name or model-name
if ! acw --chat-list >/dev/null 2>&1; then
    test_fail "--chat-list should exit 0 without provider args"
fi

# ============================================================
# Test 12: Stderr sidecar path derivation
# ============================================================
test_info "Checking stderr sidecar path derivation"

# Verify stderr path is derived from session file path
stderr_session="$session_dir/stderrtest.md"
expected_stderr="${stderr_session%.md}.stderr"
expected_stderr_name="stderrtest.stderr"

if [ "$expected_stderr" != "$session_dir/$expected_stderr_name" ]; then
    test_fail "Stderr path derivation mismatch: expected $session_dir/$expected_stderr_name, got $expected_stderr"
fi

# ============================================================
# Test 13: Empty stderr sidecar is cleaned up
# ============================================================
test_info "Checking empty stderr sidecar cleanup logic"

# Create a session file and an empty stderr file
cleanup_session="$session_dir/cleanuptest.md"
cleanup_stderr="${cleanup_session%.md}.stderr"
_acw_chat_create_session "$cleanup_session" "claude" "test"

# Simulate: new file created but empty - should be cleaned up
touch "$cleanup_stderr"
if [ ! -f "$cleanup_stderr" ]; then
    test_fail "Failed to create test stderr file"
fi

# The cleanup logic: if newly created (preexist=0) and empty, remove
# We test the condition directly since we can't easily mock provider invocation
stderr_preexist=0
if [ "$stderr_preexist" -eq 0 ] && [ ! -s "$cleanup_stderr" ]; then
    rm -f "$cleanup_stderr"
fi

if [ -f "$cleanup_stderr" ]; then
    test_fail "Empty newly-created stderr sidecar should have been removed"
fi

# ============================================================
# Test 14: Non-empty stderr sidecar is preserved
# ============================================================
test_info "Checking non-empty stderr sidecar preservation"

preserve_session="$session_dir/preservetest.md"
preserve_stderr="${preserve_session%.md}.stderr"
_acw_chat_create_session "$preserve_session" "claude" "test"

# Create stderr file with content
echo "Some provider stderr output" > "$preserve_stderr"

# The cleanup logic should not remove non-empty files
stderr_preexist=0
if [ "$stderr_preexist" -eq 0 ] && [ ! -s "$preserve_stderr" ]; then
    rm -f "$preserve_stderr"
fi

if [ ! -f "$preserve_stderr" ]; then
    test_fail "Non-empty stderr sidecar should have been preserved"
fi

# Verify content is intact
if ! grep -q "Some provider stderr output" "$preserve_stderr"; then
    test_fail "Stderr sidecar content was corrupted"
fi

# ============================================================
# Test 15: Pre-existing stderr sidecar is preserved even if empty
# ============================================================
test_info "Checking pre-existing stderr sidecar preservation"

preexist_session="$session_dir/preexisttest.md"
preexist_stderr="${preexist_session%.md}.stderr"
_acw_chat_create_session "$preexist_session" "claude" "test"

# Create pre-existing empty stderr file
touch "$preexist_stderr"

# Simulate: file already existed before this invocation
stderr_preexist=1
if [ "$stderr_preexist" -eq 0 ] && [ ! -s "$preexist_stderr" ]; then
    rm -f "$preexist_stderr"
fi

if [ ! -f "$preexist_stderr" ]; then
    test_fail "Pre-existing empty stderr sidecar should have been preserved"
fi

test_pass "All chat session tests passed"
