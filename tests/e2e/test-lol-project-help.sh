#!/usr/bin/env bash
# Test: lol project --help shows usage information

source "$(dirname "$0")/../common.sh"

test_info "lol project --help shows usage information"

# Check that lol-cli.sh contains project subcommand help
if grep -q "lol project --create" "$PROJECT_ROOT/scripts/lol-cli.sh" && \
   grep -q "lol project --associate" "$PROJECT_ROOT/scripts/lol-cli.sh" && \
   grep -q "lol project --automation" "$PROJECT_ROOT/scripts/lol-cli.sh"; then
    test_pass "Help text includes all project subcommands"
else
    test_fail "Help text incomplete"
fi
