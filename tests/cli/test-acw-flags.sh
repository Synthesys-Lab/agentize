#!/usr/bin/env bash
# Test: acw --editor and --stdout flag behavior
# Test 1: --editor fails when EDITOR is unset
# Test 2: --editor rejects empty/whitespace-only content
# Test 3: --editor uses editor content as input
# Test 4: --stdout merges provider stderr into stdout
# Test 5: file mode captures provider stderr to sidecar
# Test 6: file mode removes empty stderr sidecar
# Test 7: --stdout rejects output-file positional argument
# Test 8: --chat --editor --stdout echoes prompt on TTY stdout
# Test 9: --chat --editor --stdout skips prompt echo on non-TTY stdout

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw --editor/--stdout flag behavior"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

TEST_HOME=$(make_temp_dir "test-acw-flags-$$")
TEST_BIN="$TEST_HOME/bin"
mkdir -p "$TEST_BIN"

# Stub claude provider binary
cat > "$TEST_BIN/claude" << 'STUB'
#!/usr/bin/env bash
input_file=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-p" ]; then
    input_file="$arg"
    prev=""
    continue
  fi
  if [ "$arg" = "-p" ]; then
    prev="-p"
    continue
  fi
done

if [ -n "$input_file" ]; then
  case "$input_file" in
    @*) input_file="${input_file#@}" ;;
  esac
fi

if [ -n "$input_file" ] && [ -f "$input_file" ]; then
  cat "$input_file"
fi

if [ "${ACW_STUB_STDERR:-1}" != "0" ]; then
  echo "stub-stderr" >&2
fi
STUB
chmod +x "$TEST_BIN/claude"

export PATH="$TEST_BIN:$PATH"

# Test 1: Error when EDITOR is unset
unset EDITOR
set +e
output=$(acw --editor claude test-model "$TEST_HOME/out.txt" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when EDITOR is unset"
fi

if ! echo "$output" | grep -q "EDITOR is not set"; then
  test_fail "--editor error message should mention EDITOR is not set"
fi

# Test 2: Error when editor writes whitespace only
EMPTY_EDITOR="$TEST_HOME/empty-editor.sh"
cat > "$EMPTY_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "   " > "$1"
STUB
chmod +x "$EMPTY_EDITOR"

export EDITOR="$EMPTY_EDITOR"
set +e
output=$(acw --editor claude test-model "$TEST_HOME/out.txt" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should reject empty/whitespace-only content"
fi

if ! echo "$output" | grep -qi "empty"; then
  test_fail "--editor empty content error should mention 'empty'"
fi

# Test 3: Editor writes content and it's used as input
WRITE_EDITOR="$TEST_HOME/write-editor.sh"
cat > "$WRITE_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "Content from editor" > "$1"
STUB
chmod +x "$WRITE_EDITOR"

export EDITOR="$WRITE_EDITOR"
output_file="$TEST_HOME/response.txt"
set +e
acw --editor claude test-model "$output_file" >/dev/null 2>&1
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--editor with valid editor should succeed"
fi

if ! grep -q "Content from editor" "$output_file"; then
  test_fail "Output should contain editor content"
fi

# Test 4: --stdout merges provider stderr into stdout
input_file="$TEST_HOME/input.txt"
echo "Input content" > "$input_file"

set +e
merged_output=$(acw --stdout claude test-model "$input_file" 2>/dev/null)
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--stdout should succeed with valid input"
fi

if ! echo "$merged_output" | grep -q "Input content"; then
  test_fail "--stdout output should include provider stdout"
fi

if ! echo "$merged_output" | grep -q "stub-stderr"; then
  test_fail "--stdout output should include provider stderr"
fi

# Test 5: file mode captures provider stderr to sidecar
output_file="$TEST_HOME/file-response.txt"
sidecar_file="${output_file}.stderr"
stderr_capture="$TEST_HOME/file-mode-stderr.txt"
export ACW_STUB_STDERR="1"
rm -f "$output_file" "$sidecar_file" "$stderr_capture"

set +e
acw claude test-model "$input_file" "$output_file" >/dev/null 2>"$stderr_capture"
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "file mode should succeed with valid input"
fi

if [ ! -f "$sidecar_file" ]; then
  test_fail "file mode should create stderr sidecar file"
fi

if ! grep -q "stub-stderr" "$sidecar_file"; then
  test_fail "stderr sidecar should contain provider stderr"
fi

if [ -s "$stderr_capture" ]; then
  test_fail "file mode should keep provider stderr out of terminal"
fi

# Test 6: file mode removes empty stderr sidecar
output_file="$TEST_HOME/empty-stderr-response.txt"
sidecar_file="${output_file}.stderr"
stderr_capture="$TEST_HOME/empty-stderr-terminal.txt"
export ACW_STUB_STDERR="0"
rm -f "$output_file" "$sidecar_file" "$stderr_capture"

set +e
acw claude test-model "$input_file" "$output_file" >/dev/null 2>"$stderr_capture"
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "file mode should succeed when provider writes no stderr"
fi

if [ -f "$sidecar_file" ]; then
  test_fail "empty stderr sidecar should be removed"
fi

if [ -s "$stderr_capture" ]; then
  test_fail "file mode should keep terminal stderr quiet when provider writes none"
fi

export ACW_STUB_STDERR="1"

# Test 7: --stdout rejects output-file positional argument
set +e
output=$(acw --stdout claude test-model "$input_file" "$TEST_HOME/out.txt" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--stdout should fail when output-file is provided"
fi

if ! echo "$output" | grep -qi "stdout"; then
  test_fail "--stdout mutual exclusion error should mention stdout"
fi

# Test 8: --chat --editor --stdout echoes prompt on TTY stdout
TTY_EDITOR="$TEST_HOME/tty-editor.sh"
cat > "$TTY_EDITOR" << 'STUB'
#!/usr/bin/env bash
cat > "$1" << 'EOF'
TTY prompt content
EOF
STUB
chmod +x "$TTY_EDITOR"

if ! command -v script >/dev/null 2>&1; then
  test_fail "script command is required for TTY stdout testing"
fi

TTY_RUNNER="$TEST_HOME/tty-run.sh"
cat > "$TTY_RUNNER" << STUB
#!/usr/bin/env bash
source "$ACW_CLI"
acw --chat --editor --stdout claude test-model
STUB
chmod +x "$TTY_RUNNER"

script_flavor="bsd"
if script --version >/dev/null 2>&1; then
  script_flavor="util-linux"
fi

test_info "script path: $(command -v script)"
test_info "script flavor: $script_flavor"
if [ "$script_flavor" = "util-linux" ]; then
  test_info "script version: $(script --version 2>&1 | head -n1)"
fi

ORIGINAL_AGENTIZE_HOME="$AGENTIZE_HOME"
CHAT_HOME="$TEST_HOME/chat-home"
mkdir -p "$CHAT_HOME"

export AGENTIZE_HOME="$CHAT_HOME"
export EDITOR="$TTY_EDITOR"
export ACW_STUB_STDERR="0"

set +e
if [ "$script_flavor" = "util-linux" ]; then
  tty_output=$(script -q -c "bash \"$TTY_RUNNER\"" /dev/null 2>/dev/null)
else
  tty_output=$(script -q /dev/null bash "$TTY_RUNNER" 2>/dev/null)
fi
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_info "script stdout (first 40 lines):"
  printf "%s\n" "$tty_output" | sed -n '1,40p'
  test_fail "--chat --editor --stdout should succeed on TTY stdout"
fi

clean_tty_output=$(printf "%s\n" "$tty_output" | tr -d '\r')

if ! printf "%s\n" "$clean_tty_output" | grep -q "^User Prompt:"; then
  test_fail "TTY stdout should include User Prompt header"
fi

if ! printf "%s\n" "$clean_tty_output" | grep -q "TTY prompt content"; then
  test_fail "TTY stdout should include editor prompt content"
fi

prompt_line=$(printf "%s\n" "$clean_tty_output" | awk '/^User Prompt:/{print NR; exit}')
user_header_line=$(printf "%s\n" "$clean_tty_output" | awk '/^# User/{print NR; exit}')

if [ -z "$prompt_line" ] || [ -z "$user_header_line" ]; then
  test_fail "TTY stdout should include prompt header and assistant output"
fi

if [ "$prompt_line" -gt "$user_header_line" ]; then
  test_fail "TTY stdout should echo prompt before assistant output"
fi

# Test 9: --chat --editor --stdout skips prompt echo on non-TTY stdout
set +e
non_tty_output=$(acw --chat --editor --stdout claude test-model 2>/dev/null)
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--chat --editor --stdout should succeed on non-TTY stdout"
fi

clean_non_tty_output=$(printf "%s\n" "$non_tty_output" | tr -d '\r')

if printf "%s\n" "$clean_non_tty_output" | grep -q "^User Prompt:"; then
  test_fail "Non-TTY stdout should not include prompt echo"
fi

if ! printf "%s\n" "$clean_non_tty_output" | grep -q "TTY prompt content"; then
  test_fail "Non-TTY stdout should still include assistant output"
fi

export AGENTIZE_HOME="$ORIGINAL_AGENTIZE_HOME"

test_pass "acw --editor/--stdout flags work correctly"
