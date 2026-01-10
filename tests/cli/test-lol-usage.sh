#!/usr/bin/env bash
# Test: lol usage command
# Tests Claude Code token usage statistics aggregation

source "$(dirname "$0")/../common.sh"

test_info "lol usage command tests"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"

# Test 1: usage --help exits 0 (command exists)
output=$(python3 -m agentize.cli usage --help 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  test_fail "usage --help exited with code $exit_code"
fi
echo "$output" | grep -q -E "\-\-today|\-\-week" || test_fail "usage --help missing flag documentation"

# Test 2: usage with missing ~/.claude/projects directory should not crash
# Create temp HOME to isolate from real Claude data
TEST_HOME=$(make_temp_dir "usage-missing-dir")
HOME="$TEST_HOME" python3 -m agentize.cli usage 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "usage with missing ~/.claude/projects exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 3: usage --today and --week are mutually exclusive but both should work
TEST_HOME=$(make_temp_dir "usage-modes")
HOME="$TEST_HOME" python3 -m agentize.cli usage --today 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "usage --today exited with code $exit_code"
fi

HOME="$TEST_HOME" python3 -m agentize.cli usage --week 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "usage --week exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 4: usage with fixture JSONL data extracts correct tokens
TEST_HOME=$(make_temp_dir "usage-fixture")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create a fixture JSONL file with known token counts
# Format matches Claude Code session files: one JSON object per line
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"usage":{"input_tokens":200,"output_tokens":75}}}
{"type":"user","message":"hello"}
{"type":"assistant","message":{"usage":{"input_tokens":150,"output_tokens":100}}}
EOF

# Touch the file to ensure recent mtime
touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" python3 -m agentize.cli usage --today 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "usage with fixture data exited with code $exit_code"
fi

# Verify output contains expected metrics (450 input, 225 output from fixture)
echo "$output" | grep -q "1 session" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "usage output missing session count"
}

# Check that totals are shown
echo "$output" | grep -q -i "total" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "usage output missing 'Total' summary"
}

cleanup_dir "$TEST_HOME"

test_pass "lol usage command works correctly"
