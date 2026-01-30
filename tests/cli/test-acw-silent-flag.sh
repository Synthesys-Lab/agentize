#!/usr/bin/env bash
# Test: acw --silent suppresses provider stderr without hiding acw errors

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw --silent behavior"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "acw-silent-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub claude command that logs args and writes stderr
cat > "$TMP_DIR/claude" << 'STUB'
#!/usr/bin/env bash
echo "provider-stderr" >&2
echo "$@" > "$ARGS_LOG_FILE"
echo "stub response"
STUB
chmod +x "$TMP_DIR/claude"

# Prepend stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"

# Source the acw module
source "$ACW_CLI"

# Case 1: provider stderr visible without --silent
export ARGS_LOG_FILE="$TMP_DIR/args-default.log"
acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output-default.txt" --max-tokens 111 2> "$TMP_DIR/stderr-default.txt"

if ! grep -q "provider-stderr" "$TMP_DIR/stderr-default.txt"; then
    test_fail "Expected provider stderr without --silent"
fi

if ! grep -q "stub response" "$TMP_DIR/output-default.txt"; then
    test_fail "Expected response content without --silent"
fi

# Case 2: provider stderr suppressed with --silent
export ARGS_LOG_FILE="$TMP_DIR/args-silent.log"
acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output-silent.txt" --silent --max-tokens 222 2> "$TMP_DIR/stderr-silent.txt"

if [ -s "$TMP_DIR/stderr-silent.txt" ]; then
    test_fail "Expected provider stderr to be suppressed with --silent"
fi

if ! grep -q "stub response" "$TMP_DIR/output-silent.txt"; then
    test_fail "Expected response content with --silent"
fi

if grep -q -- "--silent" "$TMP_DIR/args-silent.log"; then
    test_fail "--silent was forwarded to the provider"
fi

if ! grep -q -- "--max-tokens" "$TMP_DIR/args-silent.log"; then
    test_fail "Expected provider options to be forwarded"
fi

# Case 3: validation errors remain visible with --silent
set +e
acw --silent 2> "$TMP_DIR/stderr-validate.txt"
status=$?
set -e

if [ $status -eq 0 ]; then
    test_fail "Expected validation failure for missing args"
fi

if ! grep -q "Missing model-name argument" "$TMP_DIR/stderr-validate.txt"; then
    test_fail "Expected validation error output with --silent"
fi

# Case 4: completion includes --silent
completion=$(acw --complete cli-options)
if ! echo "$completion" | grep -q -- "--silent"; then
    test_fail "Expected --silent in cli-options completion"
fi

test_pass "acw --silent suppresses provider stderr and preserves acw errors"
