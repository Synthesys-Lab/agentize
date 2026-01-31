#!/usr/bin/env bash
# Test: acw --yolo translation for Claude provider
# Verifies that --yolo is translated to --dangerously-skip-permissions when invoking Claude

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing --yolo translation for Claude provider"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "acw-yolo-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub claude command that logs its arguments
cat > "$TMP_DIR/claude" << 'STUB'
#!/usr/bin/env bash
# Log all arguments to a file for verification
echo "$@" > "$ARGS_LOG_FILE"
# Write dummy output
echo "stub response"
STUB
chmod +x "$TMP_DIR/claude"

# Prepend our stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"
export ARGS_LOG_FILE="$TMP_DIR/args.log"
export AGENTIZE_HOME="$PROJECT_ROOT"

# Source the acw module
source "$ACW_CLI"

# Test: invoke acw with claude and --yolo flag
test_info "Invoking acw claude with --yolo flag"
acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output.txt" --yolo

# Check if the args log contains --dangerously-skip-permissions instead of --yolo
if [ ! -f "$ARGS_LOG_FILE" ]; then
    test_fail "Claude stub was not invoked - args log file missing"
fi

logged_args=$(cat "$ARGS_LOG_FILE")
test_info "Logged args: $logged_args"

if echo "$logged_args" | grep -q -- "--yolo"; then
    test_fail "--yolo was passed directly to Claude instead of being translated"
fi

if ! echo "$logged_args" | grep -q -- "--dangerously-skip-permissions"; then
    test_fail "--yolo was not translated to --dangerously-skip-permissions"
fi

test_pass "--yolo correctly translated to --dangerously-skip-permissions for Claude"
