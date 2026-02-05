#!/usr/bin/env bash
# Test: acw Kimi stream-json stripping
# Test 1: NDJSON input yields concatenated text
# Test 2: JSON payload yields text
# Test 3: Mixed non-JSON line is ignored
# Test 4: Chat mode stores stripped assistant text

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw Kimi stream-json stripping"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

TEST_HOME=$(make_temp_dir "test-acw-kimi-stripper-$$")
TEST_BIN="$TEST_HOME/bin"
mkdir -p "$TEST_BIN"

cat > "$TEST_BIN/kimi" << 'STUB'
#!/usr/bin/env bash
cat >/dev/null
case "$KIMI_MODE" in
  ndjson)
    printf '%s\n' '{"content":[{"type":"text","text":"Hello "}]}'
    printf '%s\n' '{"content":[{"type":"text","text":"World"}]}'
    ;;
  json)
    printf '%s\n' '{"content":[{"type":"text","text":"Solo"}]}'
    ;;
  mixed)
    echo "progress line"
    printf '%s\n' '{"content":[{"type":"text","text":"Mixed"}]}'
    ;;
  chat)
    printf '%s\n' '{"content":[{"type":"text","text":"Chat reply"}]}'
    ;;
  *)
    printf '%s\n' '{"content":[{"type":"text","text":"Default"}]}'
    ;;
esac
STUB
chmod +x "$TEST_BIN/kimi"

export PATH="$TEST_BIN:$PATH"

input_file="$TEST_HOME/input.txt"
echo "Prompt" > "$input_file"

# Test 1: NDJSON input yields concatenated text
export KIMI_MODE="ndjson"
output_file="$TEST_HOME/ndjson.txt"
set +e
acw kimi default "$input_file" "$output_file" >/dev/null 2>&1
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "Kimi NDJSON stripping should succeed"
fi

output=$(cat "$output_file")
if [ "$output" != "Hello World" ]; then
  test_fail "NDJSON output should be concatenated into plain text"
fi

# Test 2: JSON payload yields text
export KIMI_MODE="json"
output_file="$TEST_HOME/json.txt"
set +e
acw kimi default "$input_file" "$output_file" >/dev/null 2>&1
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "Kimi JSON stripping should succeed"
fi

output=$(cat "$output_file")
if [ "$output" != "Solo" ]; then
  test_fail "JSON output should be stripped to plain text"
fi

# Test 3: Mixed non-JSON line is ignored
export KIMI_MODE="mixed"
output_file="$TEST_HOME/mixed.txt"
set +e
acw kimi default "$input_file" "$output_file" >/dev/null 2>&1
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "Kimi mixed output stripping should succeed"
fi

output=$(cat "$output_file")
if [ "$output" != "Mixed" ]; then
  test_fail "Mixed output should ignore non-JSON lines"
fi

# Test 4: Chat mode stores stripped assistant text
CHAT_HOME="$TEST_HOME/chat-home"
mkdir -p "$CHAT_HOME"
ORIGINAL_AGENTIZE_HOME="$AGENTIZE_HOME"
export AGENTIZE_HOME="$CHAT_HOME"
export KIMI_MODE="chat"
chat_output="$TEST_HOME/chat-output.txt"
chat_stderr="$TEST_HOME/chat-stderr.txt"
set +e
acw --chat kimi default "$input_file" "$chat_output" 2>"$chat_stderr"
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "Kimi chat mode should succeed"
fi

session_id=$(sed -n 's/^Session: //p' "$chat_stderr" | head -n1)
if [ -z "$session_id" ]; then
  test_fail "Kimi chat mode should emit a session ID"
fi

session_file="$CHAT_HOME/.tmp/acw-sessions/${session_id}.md"
if [ ! -f "$session_file" ]; then
  test_fail "Kimi chat session file should exist"
fi

if ! grep -q "Chat reply" "$session_file"; then
  test_fail "Kimi chat session should store stripped assistant text"
fi

if grep -q '"content"' "$session_file"; then
  test_fail "Kimi chat session should not store raw JSON content"
fi

if ! grep -q "Chat reply" "$chat_output"; then
  test_fail "Kimi chat output file should contain stripped text"
fi

export AGENTIZE_HOME="$ORIGINAL_AGENTIZE_HOME"

test_pass "acw Kimi stream-json stripping works correctly"
