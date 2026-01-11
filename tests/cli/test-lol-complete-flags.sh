#!/usr/bin/env bash
# Test: lol --complete flag topics output documented flags

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol --complete flag topics output documented flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test apply-flags
apply_output=$(lol --complete apply-flags 2>/dev/null)

echo "$apply_output" | grep -q "^--init$" || test_fail "apply-flags missing: --init"
echo "$apply_output" | grep -q "^--update$" || test_fail "apply-flags missing: --update"

# Test init-flags
init_output=$(lol --complete init-flags 2>/dev/null)

echo "$init_output" | grep -q "^--name$" || test_fail "init-flags missing: --name"
echo "$init_output" | grep -q "^--lang$" || test_fail "init-flags missing: --lang"
echo "$init_output" | grep -q "^--path$" || test_fail "init-flags missing: --path"
echo "$init_output" | grep -q "^--source$" || test_fail "init-flags missing: --source"
echo "$init_output" | grep -q "^--metadata-only$" || test_fail "init-flags missing: --metadata-only"

# Test update-flags
update_output=$(lol --complete update-flags 2>/dev/null)

echo "$update_output" | grep -q "^--path$" || test_fail "update-flags missing: --path"

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

# Test lang-values
lang_output=$(lol --complete lang-values 2>/dev/null)

echo "$lang_output" | grep -q "^c$" || test_fail "lang-values missing: c"
echo "$lang_output" | grep -q "^cxx$" || test_fail "lang-values missing: cxx"
echo "$lang_output" | grep -q "^python$" || test_fail "lang-values missing: python"

# Verify output is newline-delimited
if echo "$init_output" | grep -q " "; then
  test_fail "init-flags output should be newline-delimited"
fi

if echo "$lang_output" | grep -q " "; then
  test_fail "lang-values output should be newline-delimited"
fi

# Test unknown topic returns empty
unknown_output=$(lol --complete unknown-topic 2>/dev/null)
if [ -n "$unknown_output" ]; then
  test_fail "Unknown topic should return empty output"
fi

test_pass "lol --complete flag topics output correct flags"
