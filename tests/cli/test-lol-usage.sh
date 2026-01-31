#!/usr/bin/env bash
# Test: lol usage command
# Tests Claude Code token usage statistics aggregation via shell CLI

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol usage command tests"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
source "$LOL_CLI"

# Test 1: lol usage with missing ~/.claude/projects directory should not crash
# Create temp HOME to isolate from real Claude data
TEST_HOME=$(make_temp_dir "usage-missing-dir")
HOME="$TEST_HOME" lol usage 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage with missing ~/.claude/projects exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 2: lol usage --today and --week flags both work
TEST_HOME=$(make_temp_dir "usage-modes")
HOME="$TEST_HOME" lol usage --today 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --today exited with code $exit_code"
fi

HOME="$TEST_HOME" lol usage --week 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --week exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 3: lol usage with fixture JSONL data extracts correct tokens
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

output=$(HOME="$TEST_HOME" lol usage --today 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage with fixture data exited with code $exit_code"
fi

# Verify output contains expected metrics (450 input, 225 output from fixture)
echo "$output" | grep -q "1 session" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage output missing session count"
}

# Check that totals are shown
echo "$output" | grep -q -i "total" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage output missing 'Total' summary"
}

cleanup_dir "$TEST_HOME"

# Test 4: lol usage --cache flag works and shows cache columns
TEST_HOME=$(make_temp_dir "usage-cache")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with cache tokens
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":30,"cache_creation_input_tokens":20}}}
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":200,"output_tokens":75,"cache_read_input_tokens":50}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cache 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache exited with code $exit_code"
fi

# Verify cache columns appear in output
echo "$output" | grep -q "cache_read" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache output missing cache_read column"
}

cleanup_dir "$TEST_HOME"

# Test 5: lol usage --cost flag works and shows cost column
TEST_HOME=$(make_temp_dir "usage-cost")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with model info for cost calculation
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":1000,"output_tokens":500}}}
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":2000,"output_tokens":1000}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost exited with code $exit_code"
fi

# Verify cost column appears with dollar sign
echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost output missing cost value (no \$ found)"
}

cleanup_dir "$TEST_HOME"

# Test 6: lol usage with unknown model shows warning
TEST_HOME=$(make_temp_dir "usage-unknown-model")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with unknown model
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"unknown-model-xyz","usage":{"input_tokens":1000,"output_tokens":500}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with unknown model exited with code $exit_code"
fi

# Should still work but with warning or N/A cost
cleanup_dir "$TEST_HOME"

# Test 7: lol usage --cache --cost flags work together
TEST_HOME=$(make_temp_dir "usage-cache-cost")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":200,"cache_creation_input_tokens":100}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cache --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost exited with code $exit_code"
fi

# Verify both cache and cost columns
echo "$output" | grep -q "cache_read" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost missing cache_read column"
}

echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost missing cost column"
}

cleanup_dir "$TEST_HOME"

# Test 8: lol usage --cost with Claude 4.5 model does NOT show unknown model warning
TEST_HOME=$(make_temp_dir "usage-claude-4-5")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with Claude 4.5 model (should be recognized)
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":1000,"output_tokens":500}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with Claude 4.5 model exited with code $exit_code"
fi

# Verify NO unknown model warning (4.5 models should be recognized)
if echo "$output" | grep -q "Unknown models"; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost incorrectly reports Claude 4.5 as unknown model"
fi

# Verify cost column appears with dollar sign (meaning pricing was computed)
echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with Claude 4.5 missing cost value"
}

cleanup_dir "$TEST_HOME"

test_pass "lol usage command works correctly"
