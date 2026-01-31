#!/usr/bin/env bash
# Test: acw usage text includes documented commands and providers

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw usage text includes documented commands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Get usage text from acw (no arguments shows usage)
# Note: acw returns exit code 1 when showing help, so we need to handle this
output=$(acw 2>&1 || true)

# Verify usage text shows the command format
echo "$output" | grep -q "acw <cli-name>" || test_fail "Usage text missing 'acw <cli-name>' pattern"

# Verify usage text includes claude provider
echo "$output" | grep -q "claude" || test_fail "Usage text missing 'claude' provider"

# Verify usage text includes codex provider
echo "$output" | grep -q "codex" || test_fail "Usage text missing 'codex' provider"

# Verify usage text includes --help flag
echo "$output" | grep -q "\-\-help" || test_fail "Usage text missing '--help' flag"

# Verify usage text includes --silent flag
echo "$output" | grep -q "\-\-silent" || test_fail "Usage text missing '--silent' flag"

# Verify usage text mentions input-file and output-file
echo "$output" | grep -q "input-file" || test_fail "Usage text missing 'input-file' argument"
echo "$output" | grep -q "output-file" || test_fail "Usage text missing 'output-file' argument"

test_pass "acw usage text includes documented commands"
