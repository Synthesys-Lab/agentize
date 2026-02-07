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

echo "$output" | grep -q "Usage: lol simp" || {
  echo "Output: $output" >&2
  test_fail "Expected usage message for lol simp"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when args are invalid"
fi

# Test 6: lol simp rejects extra args (more than file + focus)
: > "$PYTHON_LOG"
output=$(lol simp README.md "focus text" extra-arg 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should fail with more than two positional arguments"
}

echo "$output" | grep -q "Usage: lol simp" || {
  echo "Output: $output" >&2
  test_fail "Expected usage message for lol simp"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when args are invalid"
fi

# Test 7: lol simp with positional focus description (treated as file if exists)
: > "$PYTHON_LOG"
output=$(lol simp "nonexistent-file-that-is-focus" 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept positional description when not a file"
}

if ! grep -q 'python -m agentize.cli simp --focus nonexistent-file-that-is-focus' "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected positional description to be forwarded as --focus"
fi

# Test 8: lol simp with --focus flag
: > "$PYTHON_LOG"
output=$(lol simp --focus "Refactor for clarity" 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept --focus flag"
}

if ! grep -q 'python -m agentize.cli simp --focus Refactor for clarity' "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected --focus to be forwarded to python -m agentize.cli simp"
fi

# Test 9: lol simp with file and --focus
: > "$PYTHON_LOG"
output=$(lol simp README.md --focus "Refactor for clarity" 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept file with --focus"
}

if ! grep -q 'python -m agentize.cli simp README.md --focus Refactor for clarity' "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected file and --focus to be forwarded to python -m agentize.cli simp"
fi

# Test 10: lol simp with --editor
# Create a fake editor that writes focus text
FAKE_EDITOR="$TMP_DIR/fake-editor"
cat <<'FAKEEDITOR_EOF' > "$FAKE_EDITOR"
#!/usr/bin/env bash
echo "Editor focus text" > "$1"
FAKEEDITOR_EOF
chmod +x "$FAKE_EDITOR"

: > "$PYTHON_LOG"
output=$(EDITOR="$FAKE_EDITOR" lol simp --editor 2>&1) || {
  echo "Output: $output" >&2
  test_fail "lol simp should accept --editor flag"
}

if ! grep -q 'python -m agentize.cli simp --focus Editor focus text' "$PYTHON_LOG"; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "Expected --editor to invoke fake editor and forward focus text"
fi

# Test 11: lol simp --editor fails without EDITOR
: > "$PYTHON_LOG"
output=$(EDITOR="" lol simp --editor 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp --editor should fail when EDITOR is not set"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when EDITOR is not set"
fi

# Test 12: lol simp rejects --editor and --focus together
: > "$PYTHON_LOG"
output=$(EDITOR="$FAKE_EDITOR" lol simp --editor --focus "test" 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should reject --editor and --focus together"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when --editor and --focus are both used"
fi

# Test 13: lol simp rejects --editor and positional focus together
: > "$PYTHON_LOG"
output=$(EDITOR="$FAKE_EDITOR" lol simp --editor "positional focus" 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should reject --editor with positional focus"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when --editor with positional focus"
fi

# Test 14: lol simp rejects multiple --focus
: > "$PYTHON_LOG"
output=$(lol simp --focus "first" --focus "second" 2>&1) && {
  echo "Output: $output" >&2
  test_fail "lol simp should reject multiple --focus flags"
}

if [ -s "$PYTHON_LOG" ]; then
  echo "Python log:" >&2
  cat "$PYTHON_LOG" >&2
  test_fail "lol simp should not invoke python when multiple --focus flags"
fi

test_pass "lol simp argument handling and delegation"
