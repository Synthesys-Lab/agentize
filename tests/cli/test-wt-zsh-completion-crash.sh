#!/usr/bin/env bash
# Test: zsh completion for wt spawn and wt remove does not crash

source "$(dirname "$0")/../common.sh"

test_info "zsh completion for wt spawn/remove does not crash"

# Skip if zsh is not available
if ! command -v zsh >/dev/null 2>&1; then
  echo "Skipping: zsh not available"
  exit 0
fi

COMPLETION_FILE="$PROJECT_ROOT/scripts/completions/_wt"

if [ ! -f "$COMPLETION_FILE" ]; then
  test_fail "Completion file not found: $COMPLETION_FILE"
fi

# Test case 1: wt spawn with issue number
test_info "Test case 1: wt spawn 23<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/scripts/completions' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  # Mock wt command for completion helper
  wt() { true; }

  # Simulate tab completion for 'wt spawn 23'
  words=(wt spawn 23)
  CURRENT=3
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn completion crashes with 'doubled rest argument' error"
fi

# Test case 2: wt spawn with flag before issue number
test_info "Test case 2: wt spawn --yolo 23<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/scripts/completions' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt spawn --yolo 23)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn --yolo 23 completion crashes with 'doubled rest argument' error"
fi

# Test case 3: wt spawn with flag after issue number
test_info "Test case 3: wt spawn 23 --yolo<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/scripts/completions' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt spawn 23 --yolo)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt spawn 23 --yolo completion crashes with 'doubled rest argument' error"
fi

# Test case 4: wt remove with flag
test_info "Test case 4: wt remove 23 --force<tab>"
output=$(zsh -fc "
  fpath=('$PROJECT_ROOT/scripts/completions' \$fpath)
  autoload -Uz compinit && compinit
  autoload -Uz _wt

  wt() { true; }

  words=(wt remove 23 --force)
  CURRENT=4
  _wt 2>&1
" 2>&1)

if echo "$output" | grep -q "doubled rest argument"; then
  test_fail "wt remove 23 --force completion crashes with 'doubled rest argument' error"
fi

test_pass "zsh completion does not crash with doubled rest argument"
