#!/usr/bin/env bash
# Test: agentize server module exports and re-exports

source "$(dirname "$0")/../common.sh"

test_info "agentize server module exports and re-exports"

# Test 1: All submodules import without error
test_info "Test 1: Submodules import cleanly"
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server import log
from agentize.server import notify
from agentize.server import session
from agentize.server import github
from agentize.server import workers
" || test_fail "Submodule imports failed"

# Test 2: Re-exports from __main__ work
test_info "Test 2: Re-exports from __main__ work"
python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import (
    _log,
    read_worker_status,
    write_worker_status,
    init_worker_status_files,
    get_free_worker,
    cleanup_dead_workers,
    spawn_worktree,
    worktree_exists,
    rebase_worktree,
    discover_candidate_issues,
    filter_ready_issues,
    query_issue_project_status,
    query_project_items,
    discover_candidate_prs,
    filter_conflicting_prs,
    resolve_issue_from_pr,
    send_telegram_message,
    notify_server_start,
    _format_worker_assignment_message,
    _format_worker_completion_message,
    _resolve_session_dir,
    _load_issue_index,
    _load_session_state,
    _get_session_state_for_issue,
    _remove_issue_index,
)
" || test_fail "__main__ re-exports failed"

# Test 3: Callable check for key functions
test_info "Test 3: Re-exported functions are callable"
result=$(python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import read_worker_status, _log
print(callable(read_worker_status) and callable(_log))
")
[ "$result" = "True" ] || test_fail "Re-exported functions not callable"

test_pass "agentize server module exports work correctly"
