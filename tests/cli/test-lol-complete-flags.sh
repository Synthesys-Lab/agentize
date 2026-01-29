#!/usr/bin/env bash
# Test: lol --complete flag topics output documented flags

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol --complete flag topics output documented flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test project-modes
project_modes_output=$(lol --complete project-modes 2>/dev/null)

echo "$project_modes_output" | grep -q "^--create$" || test_fail "project-modes missing: --create"
echo "$project_modes_output" | grep -q "^--associate$" || test_fail "project-modes missing: --associate"
echo "$project_modes_output" | grep -q "^--automation$" || test_fail "project-modes missing: --automation"

# Test project-create-flags
project_create_output=$(lol --complete project-create-flags 2>/dev/null)

echo "$project_create_output" | grep -q "^--org$" || test_fail "project-create-flags missing: --org"
echo "$project_create_output" | grep -q "^--title$" || test_fail "project-create-flags missing: --title"

# Test project-automation-flags
project_automation_output=$(lol --complete project-automation-flags 2>/dev/null)

echo "$project_automation_output" | grep -q "^--write$" || test_fail "project-automation-flags missing: --write"

# Test claude-clean-flags
claude_clean_output=$(lol --complete claude-clean-flags 2>/dev/null)

echo "$claude_clean_output" | grep -q "^--dry-run$" || test_fail "claude-clean-flags missing: --dry-run"

# Test usage-flags
usage_output=$(lol --complete usage-flags 2>/dev/null)

echo "$usage_output" | grep -q "^--today$" || test_fail "usage-flags missing: --today"
echo "$usage_output" | grep -q "^--week$" || test_fail "usage-flags missing: --week"
echo "$usage_output" | grep -q "^--cache$" || test_fail "usage-flags missing: --cache"
echo "$usage_output" | grep -q "^--cost$" || test_fail "usage-flags missing: --cost"

# Test plan-flags
plan_output=$(lol --complete plan-flags 2>/dev/null)

echo "$plan_output" | grep -q "^--dry-run$" || test_fail "plan-flags missing: --dry-run"
echo "$plan_output" | grep -q "^--verbose$" || test_fail "plan-flags missing: --verbose"
echo "$plan_output" | grep -q "^--refine$" || test_fail "plan-flags missing: --refine"

# Test unknown topic returns empty
unknown_output=$(lol --complete unknown-topic 2>/dev/null)
if [ -n "$unknown_output" ]; then
  test_fail "Unknown topic should return empty output"
fi

# Verify removed topics return empty (apply-flags, init-flags, update-flags, lang-values)
apply_output=$(lol --complete apply-flags 2>/dev/null)
if [ -n "$apply_output" ]; then
  test_fail "apply-flags topic should have been removed (should return empty)"
fi

init_output=$(lol --complete init-flags 2>/dev/null)
if [ -n "$init_output" ]; then
  test_fail "init-flags topic should have been removed (should return empty)"
fi

update_output=$(lol --complete update-flags 2>/dev/null)
if [ -n "$update_output" ]; then
  test_fail "update-flags topic should have been removed (should return empty)"
fi

lang_output=$(lol --complete lang-values 2>/dev/null)
if [ -n "$lang_output" ]; then
  test_fail "lang-values topic should have been removed (should return empty)"
fi

test_pass "lol --complete flag topics output correct flags"
