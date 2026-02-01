#!/usr/bin/env bash
# Test: acw --editor and --stdout flag behavior
# Test 1: --editor fails when EDITOR is unset
# Test 2: --editor rejects empty/whitespace-only content
# Test 3: --editor uses editor content as input
# Test 4: --stdout merges provider stderr into stdout
# Test 5: --stdout rejects output-file positional argument

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

echo "stub-stderr" >&2
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

# Test 5: --stdout rejects output-file positional argument
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

test_pass "acw --editor/--stdout flags work correctly"
