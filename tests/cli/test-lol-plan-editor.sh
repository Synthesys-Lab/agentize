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

# Test 1: Error when VISUAL and EDITOR are both unset
unset VISUAL
unset EDITOR

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when VISUAL and EDITOR are unset"
fi

if ! echo "$output" | grep -q "VISUAL.*EDITOR"; then
  test_fail "--editor error message should mention VISUAL and EDITOR"
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
unset VISUAL

# Mock lol_cmd_plan to capture what it receives
captured_desc=""
lol_cmd_plan() {
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

# Test 6: VISUAL takes precedence over EDITOR
VISUAL_EDITOR="$TEST_HOME/visual-editor.sh"
cat > "$VISUAL_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "From VISUAL" > "$1"
STUB
chmod +x "$VISUAL_EDITOR"

EDITOR_SCRIPT="$TEST_HOME/editor-script.sh"
cat > "$EDITOR_SCRIPT" << 'STUB'
#!/usr/bin/env bash
echo "From EDITOR" > "$1"
STUB
chmod +x "$EDITOR_SCRIPT"

export VISUAL="$VISUAL_EDITOR"
export EDITOR="$EDITOR_SCRIPT"

captured_desc=""

set +e
_lol_parse_plan --editor --dry-run
exit_code=$?
set -e

if [ "$captured_desc" != "From VISUAL" ]; then
  test_fail "VISUAL should take precedence over EDITOR, got: '$captured_desc'"
fi

test_pass "lol plan --editor flag works correctly"
