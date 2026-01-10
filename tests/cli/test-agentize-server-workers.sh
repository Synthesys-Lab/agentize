#!/usr/bin/env bash
# Test: agentize server worker status file operations

source "$(dirname "$0")/../common.sh"

test_info "agentize server worker status file operations"

# Create test directory for worker status files
TMP_DIR=$(make_temp_dir "test-server-workers")
trap 'cleanup_dir "$TMP_DIR"' EXIT

WORKERS_DIR="$TMP_DIR/workers"

# Test 1: init_worker_status_files creates N files with state=FREE
test_info "Test 1: init_worker_status_files creates status files"
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import init_worker_status_files
init_worker_status_files(3, '$WORKERS_DIR')
"

# Check files exist
[ -f "$WORKERS_DIR/worker-0.status" ] || test_fail "worker-0.status not created"
[ -f "$WORKERS_DIR/worker-1.status" ] || test_fail "worker-1.status not created"
[ -f "$WORKERS_DIR/worker-2.status" ] || test_fail "worker-2.status not created"

# Check content is state=FREE
grep -q "^state=FREE$" "$WORKERS_DIR/worker-0.status" || test_fail "worker-0 should be FREE"
grep -q "^state=FREE$" "$WORKERS_DIR/worker-1.status" || test_fail "worker-1 should be FREE"

# Test 2: write_worker_status writes correct format
test_info "Test 2: write_worker_status writes BUSY state"
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import write_worker_status
write_worker_status(1, 'BUSY', 42, 12345, '$WORKERS_DIR')
"

grep -q "^state=BUSY$" "$WORKERS_DIR/worker-1.status" || test_fail "worker-1 should be BUSY"
grep -q "^issue=42$" "$WORKERS_DIR/worker-1.status" || test_fail "worker-1 should have issue=42"
grep -q "^pid=12345$" "$WORKERS_DIR/worker-1.status" || test_fail "worker-1 should have pid=12345"

# Test 3: read_worker_status parses BUSY state correctly
test_info "Test 3: read_worker_status parses BUSY state"
result=$(python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import read_worker_status
status = read_worker_status(1, '$WORKERS_DIR')
print(f\"state={status['state']},issue={status.get('issue')},pid={status.get('pid')}\")
")

echo "$result" | grep -q "state=BUSY" || test_fail "read_worker_status should return BUSY state"
echo "$result" | grep -q "issue=42" || test_fail "read_worker_status should return issue=42"
echo "$result" | grep -q "pid=12345" || test_fail "read_worker_status should return pid=12345"

# Test 4: get_free_worker returns lowest free slot
test_info "Test 4: get_free_worker returns lowest free slot"
# Reset worker-0 to BUSY
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import write_worker_status
write_worker_status(0, 'BUSY', 10, 1111, '$WORKERS_DIR')
"

result=$(python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import get_free_worker
worker_id = get_free_worker(3, '$WORKERS_DIR')
print(worker_id)
")

# worker-0 is BUSY, worker-1 is BUSY, worker-2 is FREE -> should return 2
[ "$result" = "2" ] || test_fail "get_free_worker should return 2 (first free slot), got $result"

# Test 5: Dead PID detection (simulate a dead PID)
test_info "Test 5: Dead PID detection marks worker FREE"
# Write a BUSY status with a definitely dead PID
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import write_worker_status, cleanup_dead_workers
write_worker_status(2, 'BUSY', 99, 999999999, '$WORKERS_DIR')
cleanup_dead_workers(3, '$WORKERS_DIR')
"

# Check that worker-2 is now FREE (dead PID detected)
result=$(python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import read_worker_status
status = read_worker_status(2, '$WORKERS_DIR')
print(status['state'])
")

[ "$result" = "FREE" ] || test_fail "Dead PID should mark worker as FREE, got $result"

test_pass "agentize server worker status file operations work correctly"
