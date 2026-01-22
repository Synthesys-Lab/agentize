"""Tests for agentize.server module exports and re-exports."""

import pytest


class TestSubmoduleImports:
    """Tests for submodule imports."""

    def test_submodules_import_cleanly(self):
        """Test all submodules import without error."""
        from agentize.server import log
        from agentize.server import notify
        from agentize.server import session
        from agentize.server import github
        from agentize.server import workers


class TestMainReExports:
    """Tests for re-exports from __main__."""

    def test_re_exports_from_main(self):
        """Test re-exports from __main__ work."""
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
            filter_ready_refinements,
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

    def test_re_exported_functions_are_callable(self):
        """Test re-exported functions are callable."""
        from agentize.server.__main__ import read_worker_status, _log

        assert callable(read_worker_status)
        assert callable(_log)


class TestReviewResolutionExports:
    """Tests for review resolution workflow exports."""

    def test_review_resolution_exports(self):
        """Test review resolution functions are exported."""
        from agentize.server.__main__ import (
            filter_ready_review_prs,
            has_unresolved_review_threads,
            spawn_review_resolution,
            _cleanup_review_resolution,
        )

        assert callable(filter_ready_review_prs)
        assert callable(has_unresolved_review_threads)
        assert callable(spawn_review_resolution)
        assert callable(_cleanup_review_resolution)
