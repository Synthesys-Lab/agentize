#!/usr/bin/env bash
# Purpose: Shared helper providing gh mock setup for /open-issue skill tests
# Expected: Sourced by open-issue tests to create GitHub CLI mocks

# Source gh mock helpers (use TESTS_DIR from common.sh for shell-neutral sourcing)
source "$TESTS_DIR/helpers-gh-mock.sh"
