#!/usr/bin/env bash
# Test: python -m agentize.cli entrypoint
# Tests the Python CLI wrapper for lol commands

source "$(dirname "$0")/../common.sh"

test_info "python -m agentize.cli entrypoint tests"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"

# Test 1: --complete commands returns expected list
# Note: init and update are NOT standalone commands, they are --init and --update flags for apply
output=$(python3 -m agentize.cli --complete commands 2>&1)
echo "$output" | grep -q "^apply$" || test_fail "--complete commands missing: apply"
echo "$output" | grep -q "^upgrade$" || test_fail "--complete commands missing: upgrade"
echo "$output" | grep -q "^project$" || test_fail "--complete commands missing: project"
echo "$output" | grep -q "^claude-clean$" || test_fail "--complete commands missing: claude-clean"
# Verify init and update are NOT in commands list
if echo "$output" | grep -q "^init$"; then
  test_fail "init should not be a standalone command (use 'apply --init' instead)"
fi
if echo "$output" | grep -q "^update$"; then
  test_fail "update should not be a standalone command (use 'apply --update' instead)"
fi

# Test 2: --version exits 0 and prints expected labels
output=$(python3 -m agentize.cli --version 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  test_fail "--version exited with code $exit_code"
fi
echo "$output" | grep -q "Installation:" || test_fail "--version missing 'Installation:' label"
echo "$output" | grep -q "Last update:" || test_fail "--version missing 'Last update:' label"

# Test 3: apply --init --metadata-only creates .agentize.yaml in temp dir
TEST_DIR=$(make_temp_dir "python-cli-init-test")
python3 -m agentize.cli apply --init --name test-project --lang python --path "$TEST_DIR" --metadata-only
if [ ! -f "$TEST_DIR/.agentize.yaml" ]; then
  cleanup_dir "$TEST_DIR"
  test_fail "apply --init --metadata-only did not create .agentize.yaml"
fi
# Verify metadata content
grep -q "name: test-project" "$TEST_DIR/.agentize.yaml" || {
  cleanup_dir "$TEST_DIR"
  test_fail ".agentize.yaml missing project name"
}
grep -q "lang: python" "$TEST_DIR/.agentize.yaml" || {
  cleanup_dir "$TEST_DIR"
  test_fail ".agentize.yaml missing project lang"
}
cleanup_dir "$TEST_DIR"

# Test 4: apply --update creates .claude/ directory
TEST_DIR=$(make_temp_dir "python-cli-apply-test")
mkdir -p "$TEST_DIR"
python3 -m agentize.cli apply --update --path "$TEST_DIR"
if [ ! -d "$TEST_DIR/.claude" ]; then
  cleanup_dir "$TEST_DIR"
  test_fail "apply --update did not create .claude/"
fi
cleanup_dir "$TEST_DIR"

test_pass "python -m agentize.cli entrypoint works correctly"
