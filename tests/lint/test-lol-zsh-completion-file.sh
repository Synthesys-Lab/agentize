#!/usr/bin/env bash
# Test: zsh completion file exists and has correct structure

source "$(dirname "$0")/../common.sh"

COMPLETION_FILE="$PROJECT_ROOT/scripts/completions/_lol"

test_info "zsh completion file exists and has correct structure"

# Verify file exists
if [ ! -f "$COMPLETION_FILE" ]; then
  test_fail "Completion file not found: $COMPLETION_FILE"
fi

# Verify file contains #compdef lol directive
if ! grep -q "^#compdef lol" "$COMPLETION_FILE"; then
  test_fail "Completion file missing '#compdef lol' directive"
fi

# Verify file is not empty (should have at least 10 lines)
line_count=$(wc -l < "$COMPLETION_FILE")
if [ "$line_count" -lt 10 ]; then
  test_fail "Completion file seems too short ($line_count lines)"
fi

test_pass "zsh completion file exists with correct structure"
