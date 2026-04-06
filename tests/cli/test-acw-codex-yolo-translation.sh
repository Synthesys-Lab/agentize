#!/usr/bin/env bash
# Test: acw --yolo translation for Codex provider
# Verifies that --yolo is translated to --full-auto when invoking Codex

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing --yolo translation for Codex provider"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "acw-codex-yolo-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub codex command that logs its arguments
cat > "$TMP_DIR/codex" << 'STUB'
#!/usr/bin/env bash
# Log all arguments to a file for verification
echo "$@" > "$ARGS_LOG_FILE"
# Write dummy output to the -o file
for i in $(seq 1 $#); do
    if [ "${!i}" = "-o" ]; then
        next=$((i + 1))
        echo "stub response" > "${!next}"
        break
    fi
done
STUB
chmod +x "$TMP_DIR/codex"

# Prepend our stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"
export ARGS_LOG_FILE="$TMP_DIR/args.log"
export AGENTIZE_HOME="$PROJECT_ROOT"

# Source the acw module
source "$ACW_CLI"

# Test: invoke acw with codex and --yolo flag
test_info "Invoking acw codex with --yolo flag"
acw codex test-model "$TMP_DIR/input.txt" "$TMP_DIR/codex-output.txt" --yolo

# Check if the args log contains --full-auto instead of --yolo
if [ ! -f "$ARGS_LOG_FILE" ]; then
    test_fail "Codex stub was not invoked - args log file missing"
fi

logged_args=$(cat "$ARGS_LOG_FILE")
test_info "Logged args: $logged_args"

if echo "$logged_args" | grep -q -- "--yolo"; then
    test_fail "--yolo was passed directly to Codex instead of being translated"
fi

if ! echo "$logged_args" | grep -q -- "--full-auto"; then
    test_fail "--yolo was not translated to --full-auto for Codex"
fi

test_pass "--yolo correctly translated to --full-auto for Codex"
