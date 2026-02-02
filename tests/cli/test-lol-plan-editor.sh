#!/usr/bin/env bash
# Test: lol plan --editor flag functionality

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol plan --editor flag functionality"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create isolated test home
TEST_HOME=$(make_temp_dir "test-home-$$")
export HOME="$TEST_HOME"

# Test 1: Error when EDITOR is unset
unset EDITOR

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when EDITOR is unset"
fi

if ! echo "$output" | grep -q "EDITOR is not set"; then
  test_fail "--editor error message should mention EDITOR is not set"
fi

# Test 2: Error when --editor is combined with positional argument
export EDITOR="cat"

set +e
output=$(_lol_parse_plan --editor "positional description" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should be mutually exclusive with positional argument"
fi

if ! echo "$output" | grep -qi "cannot\|both"; then
  test_fail "--editor mutual exclusion error should be clear"
fi

# Test 3: Editor writes content and it's used as feature description
# Create a stub editor that writes content to the file
STUB_EDITOR="$TEST_HOME/stub-editor.sh"
cat > "$STUB_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "Feature description from editor" > "$1"
STUB
chmod +x "$STUB_EDITOR"

export EDITOR="$STUB_EDITOR"

# Mock _lol_cmd_plan to capture what it receives
captured_desc=""
_lol_cmd_plan() {
  captured_desc="$1"
  return 0
}

set +e
_lol_parse_plan --editor --dry-run
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--editor with valid editor should succeed"
fi

if [ "$captured_desc" != "Feature description from editor" ]; then
  test_fail "Feature description should come from editor content, got: '$captured_desc'"
fi

# Test 4: Empty file or whitespace-only content is rejected
EMPTY_EDITOR="$TEST_HOME/empty-editor.sh"
cat > "$EMPTY_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "   " > "$1"
STUB
chmod +x "$EMPTY_EDITOR"

export EDITOR="$EMPTY_EDITOR"

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should reject empty/whitespace-only content"
fi

if ! echo "$output" | grep -qi "empty"; then
  test_fail "--editor empty content error should mention 'empty'"
fi

# Test 5: Non-zero editor exit aborts
FAIL_EDITOR="$TEST_HOME/fail-editor.sh"
cat > "$FAIL_EDITOR" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$FAIL_EDITOR"

export EDITOR="$FAIL_EDITOR"

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when editor exits non-zero"
fi

# Test 6: --refine with --editor uses editor content as refinement focus
export EDITOR="$STUB_EDITOR"
captured_desc=""

set +e
_lol_parse_plan --refine 42 --editor --dry-run
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--refine with --editor should succeed"
fi

if [ "$captured_desc" != "Feature description from editor" ]; then
  test_fail "Refine with --editor should use editor content, got: '$captured_desc'"
fi

# Test 7: --refine with --editor and positional instructions concatenates
# Create a new editor stub for combined test
COMBINED_EDITOR="$TEST_HOME/combined-editor.sh"
cat > "$COMBINED_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "Editor refinement focus" > "$1"
STUB
chmod +x "$COMBINED_EDITOR"

export EDITOR="$COMBINED_EDITOR"
captured_desc=""

set +e
_lol_parse_plan --refine 42 --editor "Positional instructions" --dry-run
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--refine with --editor and positional instructions should succeed"
fi

# Check that editor text comes first, then positional instructions
if ! echo "$captured_desc" | head -1 | grep -q "Editor refinement focus"; then
  test_fail "Combined refine should have editor text first, got: '$captured_desc'"
fi

if ! echo "$captured_desc" | grep -q "Positional instructions"; then
  test_fail "Combined refine should include positional instructions, got: '$captured_desc'"
fi

# Test 8: --refine with only positional instructions (no --editor) works unchanged
unset EDITOR
export EDITOR=""
captured_desc=""

set +e
_lol_parse_plan --refine 42 "Only positional focus" --dry-run
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--refine with positional-only instructions should succeed"
fi

if [ "$captured_desc" != "Only positional focus" ]; then
  test_fail "Positional-only refine should preserve instructions, got: '$captured_desc'"
fi

test_pass "lol plan --editor flag works correctly"
