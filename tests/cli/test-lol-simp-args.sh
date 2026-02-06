#!/usr/bin/env bash
# Test: lol simp argument handling and delegation

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol simp argument handling"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

TMP_DIR=$(make_temp_dir "test-lol-simp-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

PYTHON_LOG="$TMP_DIR/python-calls.log"
touch "$PYTHON_LOG"

OVERRIDES="$TMP_DIR/shell-overrides.sh"
cat <<'OVERRIDES_EOF' > "$OVERRIDES"
python() {
  echo "python $*" >> "$PYTHON_LOG"
  return 0
}
OVERRIDES_EOF

export PYTHON_LOG
source "$OVERRIDES"

# Test 1: lol simp with no args
: > "$PYTHON_LOG"
output=$(lol simp 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should succeed with no args"
}

if ! grep -q "python -m agentize.cli simp" "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected lol simp to delegate to python -m agentize.cli simp"
fi

# Test 2: lol simp with a file
: > "$PYTHON_LOG"
output=$(lol simp README.md 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept a single file path"
}

if ! grep -q "python -m agentize.cli simp README.md" "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected file path to be forwarded to python -m agentize.cli simp"
fi

# Test 3: lol simp with issue only
: > "$PYTHON_LOG"
output=$(lol simp --issue 123 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept --issue without a file"
}

if ! grep -q "python -m agentize.cli simp --issue 123" "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected --issue to be forwarded to python -m agentize.cli simp"
fi

# Test 4: lol simp with file and issue
: > "$PYTHON_LOG"
output=$(lol simp README.md --issue 123 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept file path with --issue"
}

if ! grep -q "python -m agentize.cli simp README.md --issue 123" "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected file path and --issue to be forwarded to python -m agentize.cli simp"
fi

# Test 5: lol simp rejects missing issue value
: > "$PYTHON_LOG"
output=$(lol simp --issue 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should fail when --issue has no value"
}

echo "$output" | grep -q "Usage: lol simp \[file\] \[--issue <issue-no>\]" || {
  echo "Output: $output" >&2
  test_fail "Expected usage message for lol simp"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when args are invalid"
fi

# Test 6: lol simp rejects extra args
: > "$PYTHON_LOG"
output=$(lol simp README.md docs/cli/lol.md 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should fail with more than one argument"
}

echo "$output" | grep -q "Usage: lol simp \[file\] \[--issue <issue-no>\]" || {
  echo "Output: $output" >&2
  test_fail "Expected usage message for lol simp"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when args are invalid"
fi

test_pass "lol simp argument handling and delegation"
