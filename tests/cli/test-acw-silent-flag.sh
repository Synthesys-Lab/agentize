#!/usr/bin/env bash
# Test: acw --silent suppresses provider stderr without hiding acw errors
# Verifies provider stderr suppression, option filtering, and completion updates

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw --silent behavior"

TMP_DIR=$(make_temp_dir "acw-silent-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub claude command that logs args and writes to stderr
cat > "$TMP_DIR/claude" << 'STUB'
#!/usr/bin/env bash

echo "$@" > "$ARGS_LOG_FILE"
echo "provider stdout"
echo "provider stderr" >&2
STUB
chmod +x "$TMP_DIR/claude"

# Prepend our stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"
export ARGS_LOG_FILE="$TMP_DIR/args.log"

# Source the acw module
source "$ACW_CLI"

# Test 1: provider stderr is visible without --silent
stderr_output=$(acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output.txt" --max-tokens 5 2>&1 >/dev/null || true)
if ! echo "$stderr_output" | grep -q "provider stderr"; then
    test_fail "Provider stderr was not visible without --silent"
fi
if [ ! -f "$TMP_DIR/output.txt" ]; then
    test_fail "Output file was not created without --silent"
fi

# Test 2: provider stderr is suppressed with --silent
stderr_output=$(acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output-silent.txt" --silent --max-tokens 5 2>&1 >/dev/null || true)
if [ -n "$stderr_output" ]; then
    test_fail "Expected no stderr output with --silent, got: $stderr_output"
fi
if [ ! -f "$TMP_DIR/output-silent.txt" ]; then
    test_fail "Output file was not created with --silent"
fi
if ! grep -q "provider stdout" "$TMP_DIR/output-silent.txt"; then
    test_fail "Output file missing provider stdout with --silent"
fi

# Test 3: --silent is not forwarded to the provider
if [ ! -f "$ARGS_LOG_FILE" ]; then
    test_fail "Provider args log not created"
fi
logged_args=$(cat "$ARGS_LOG_FILE")
if echo "$logged_args" | grep -q -- "--silent"; then
    test_fail "--silent was forwarded to provider"
fi
if ! echo "$logged_args" | grep -q -- "--max-tokens"; then
    test_fail "Provider options were not forwarded"
fi

# Test 4: acw validation errors still appear with --silent
error_output=$(acw unknown-provider test-model "$TMP_DIR/input.txt" "$TMP_DIR/ignored.txt" --silent 2>&1 >/dev/null || true)
if ! echo "$error_output" | grep -q "Unknown provider"; then
    test_fail "Expected unknown provider error even with --silent"
fi

# Test 5: completion includes --silent
options_output=$(acw --complete cli-options)
if ! echo "$options_output" | grep -q "^--silent$"; then
    test_fail "--silent missing from cli-options completion"
fi

test_pass "acw --silent behavior is correct"
