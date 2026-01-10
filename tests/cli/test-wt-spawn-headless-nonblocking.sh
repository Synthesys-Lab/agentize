#!/usr/bin/env bash
# Test: wt spawn --headless returns immediately and outputs structured PID:/Log: format

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn --headless non-blocking behavior and output format"

# Create claude stub that sleeps (simulates long-running process)
create_claude_stub() {
    cat > bin/claude <<'CLAUDE_STUB'
#!/usr/bin/env bash
# Stub claude that sleeps for a few seconds
sleep 3
echo "Claude completed"
CLAUDE_STUB
    chmod +x bin/claude
}

setup_test_repo
source ./wt-cli.sh

# Create claude stub in PATH
create_claude_stub

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Test 1: wt spawn --headless returns in <2 seconds while claude stub sleeps for 3s
cd "$TEST_REPO_DIR"
start_time=$(date +%s)
spawn_output=$(wt spawn 42 --headless 2>&1)
spawn_exit=$?
end_time=$(date +%s)

elapsed=$((end_time - start_time))
if [ $elapsed -ge 2 ]; then
    cleanup_test_repo
    test_fail "wt spawn --headless took ${elapsed}s (should be <2s for non-blocking)"
fi

if [ $spawn_exit -ne 0 ]; then
    cleanup_test_repo
    test_fail "wt spawn 42 --headless failed with exit code $spawn_exit: $spawn_output"
fi

# Test 2: Output contains PID: and Log: lines
pid_line=$(echo "$spawn_output" | grep "^PID: ")
log_line=$(echo "$spawn_output" | grep "^Log: ")

if [ -z "$pid_line" ]; then
    echo "DEBUG: spawn_output = $spawn_output" >&2
    cleanup_test_repo
    test_fail "spawn output should contain 'PID: <number>' line"
fi

if [ -z "$log_line" ]; then
    echo "DEBUG: spawn_output = $spawn_output" >&2
    cleanup_test_repo
    test_fail "spawn output should contain 'Log: <path>' line"
fi

# Test 3: PID is a valid number and process is alive
pid=$(echo "$pid_line" | sed 's/^PID: //')
if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    cleanup_test_repo
    test_fail "PID should be a number, got: $pid"
fi

if ! kill -0 "$pid" 2>/dev/null; then
    cleanup_test_repo
    test_fail "PID $pid should be alive immediately after spawn"
fi

# Test 4: Log file exists at printed path
log_path=$(echo "$log_line" | sed 's/^Log: //')
if [ ! -f "$log_path" ]; then
    cleanup_test_repo
    test_fail "Log file should exist at: $log_path"
fi

# Clean up: kill the stubbed claude process
kill "$pid" 2>/dev/null || true

cleanup_test_repo
test_pass "wt spawn --headless is non-blocking with structured PID:/Log: output"
