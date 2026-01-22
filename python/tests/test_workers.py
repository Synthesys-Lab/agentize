"""Tests for agentize.server worker status file operations."""

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from agentize.server.__main__ import (
    init_worker_status_files,
    write_worker_status,
    read_worker_status,
    get_free_worker,
    cleanup_dead_workers,
)


class TestWorkerStatusFiles:
    """Tests for worker status file operations."""

    def test_init_worker_status_files_creates_files(self, tmp_path):
        """Test that init_worker_status_files creates N files with state=FREE."""
        workers_dir = tmp_path / "workers"

        init_worker_status_files(3, str(workers_dir))

        # Check files exist
        assert (workers_dir / "worker-0.status").exists()
        assert (workers_dir / "worker-1.status").exists()
        assert (workers_dir / "worker-2.status").exists()

        # Check content is state=FREE
        assert "state=FREE" in (workers_dir / "worker-0.status").read_text()
        assert "state=FREE" in (workers_dir / "worker-1.status").read_text()
        assert "state=FREE" in (workers_dir / "worker-2.status").read_text()

    def test_write_worker_status_writes_busy_state(self, tmp_path):
        """Test that write_worker_status writes BUSY state correctly."""
        workers_dir = tmp_path / "workers"
        init_worker_status_files(3, str(workers_dir))

        write_worker_status(1, "BUSY", 42, 12345, str(workers_dir))

        content = (workers_dir / "worker-1.status").read_text()
        assert "state=BUSY" in content
        assert "issue=42" in content
        assert "pid=12345" in content

    def test_read_worker_status_parses_busy_state(self, tmp_path):
        """Test that read_worker_status parses BUSY state correctly."""
        workers_dir = tmp_path / "workers"
        init_worker_status_files(3, str(workers_dir))
        write_worker_status(1, "BUSY", 42, 12345, str(workers_dir))

        status = read_worker_status(1, str(workers_dir))

        assert status["state"] == "BUSY"
        assert status.get("issue") == 42
        assert status.get("pid") == 12345

    def test_get_free_worker_returns_lowest_free_slot(self, tmp_path):
        """Test that get_free_worker returns the lowest available free slot."""
        workers_dir = tmp_path / "workers"
        init_worker_status_files(3, str(workers_dir))

        # Make worker-0 and worker-1 busy
        write_worker_status(0, "BUSY", 10, 1111, str(workers_dir))
        write_worker_status(1, "BUSY", 42, 12345, str(workers_dir))

        worker_id = get_free_worker(3, str(workers_dir))

        # worker-0 is BUSY, worker-1 is BUSY, worker-2 is FREE -> should return 2
        assert worker_id == 2

    def test_cleanup_dead_workers_marks_dead_pid_free(self, tmp_path):
        """Test that dead PID detection marks worker as FREE."""
        workers_dir = tmp_path / "workers"
        init_worker_status_files(3, str(workers_dir))

        # Write a BUSY status with a definitely dead PID
        write_worker_status(2, "BUSY", 99, 999999999, str(workers_dir))
        cleanup_dead_workers(3, str(workers_dir))

        # Check that worker-2 is now FREE (dead PID detected)
        status = read_worker_status(2, str(workers_dir))
        assert status["state"] == "FREE"


class TestRefinementSpawnAndCleanup:
    """Tests for refinement spawn and cleanup functions."""

    def test_check_issue_has_label_returns_true_when_present(self):
        """Test _check_issue_has_label returns True when label is present."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "agentize:plan\nagentize:refine\nbug\n"

        with patch("subprocess.run", return_value=mock_result):
            from agentize.server.workers import _check_issue_has_label

            result = _check_issue_has_label(42, "agentize:refine")

        assert result is True

    def test_check_issue_has_label_returns_false_when_absent(self):
        """Test _check_issue_has_label returns False when label is absent."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "agentize:plan\nbug\n"

        with patch("subprocess.run", return_value=mock_result):
            from agentize.server.workers import _check_issue_has_label

            result = _check_issue_has_label(42, "agentize:refine")

        assert result is False

    def test_check_issue_has_label_returns_false_on_gh_failure(self):
        """Test _check_issue_has_label returns False on gh failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""

        with patch("subprocess.run", return_value=mock_result):
            from agentize.server.workers import _check_issue_has_label

            result = _check_issue_has_label(42, "agentize:refine")

        assert result is False

    def test_cleanup_refinement_removes_label(self, capsys):
        """Test _cleanup_refinement calls gh issue edit to remove label."""
        captured_calls = []

        def capture_run(*args, **kwargs):
            captured_calls.append(args[0] if args else kwargs.get("args", []))
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = ""
            return mock_result

        with patch("subprocess.run", side_effect=capture_run):
            import agentize.server.workers as workers_module

            with patch.object(
                workers_module,
                "run_shell_function",
                return_value=MagicMock(returncode=0, stdout="/tmp/test"),
            ):
                from agentize.server.workers import _cleanup_refinement

                _cleanup_refinement(42)

        # Check that gh issue edit was called with --remove-label
        edit_called = any(
            "--remove-label" in str(c) and "agentize:refine" in str(c)
            for c in captured_calls
        )
        assert edit_called

    def test_spawn_refinement_is_callable_with_model_param(self):
        """Test spawn_refinement is importable, callable, and has model parameter."""
        import inspect
        from agentize.server.workers import spawn_refinement

        assert callable(spawn_refinement)

        sig = inspect.signature(spawn_refinement)
        params = list(sig.parameters.keys())
        assert "model" in params
        assert sig.parameters["model"].default is None

    def test_spawn_refinement_returns_false_on_failure(self):
        """Test spawn_refinement returns (False, None) when wt spawn fails."""
        import agentize.server.workers as workers_module

        def mock_shell_run(cmd, **kwargs):
            if "wt pathto" in cmd:
                return MagicMock(returncode=1, stdout="")
            if "wt spawn" in cmd:
                return MagicMock(returncode=1, stdout="", stderr="error: spawn failed")
            return MagicMock(returncode=0, stdout="")

        with patch.object(workers_module, "run_shell_function", side_effect=mock_shell_run):
            success, pid = workers_module.spawn_refinement(42)

        assert success is False
        assert pid is None

    def test_spawn_refinement_reuses_existing_worktree(self):
        """Test spawn_refinement skips wt spawn when worktree already exists."""
        import agentize.server.workers as workers_module

        spawn_called = []

        def mock_shell_run(cmd, **kwargs):
            if "wt spawn" in cmd:
                spawn_called.append(cmd)
                return MagicMock(returncode=0, stdout="")
            if "wt pathto" in cmd:
                return MagicMock(returncode=0, stdout="/tmp/test-worktree")
            if "wt_claim_issue_status" in cmd:
                return MagicMock(returncode=0, stdout="")
            return MagicMock(returncode=0, stdout="")

        mock_popen = MagicMock()
        mock_popen.pid = 12345

        with patch.object(workers_module, "run_shell_function", side_effect=mock_shell_run):
            with patch.object(workers_module.subprocess, "Popen", return_value=mock_popen):
                with patch.object(Path, "mkdir"):
                    with patch("builtins.open", MagicMock()):
                        success, pid = workers_module.spawn_refinement(42)

        # wt spawn should NOT be called because worktree already exists
        assert len(spawn_called) == 0

    def test_cleanup_refinement_sets_proposed_status(self, capsys):
        """Test _cleanup_refinement calls wt_claim_issue_status with Proposed."""
        import agentize.server.workers as workers_module

        captured_calls = []

        def capture_shell_run(cmd, **kwargs):
            captured_calls.append(cmd)
            return MagicMock(returncode=0, stdout="/tmp/test-worktree")

        with patch.object(workers_module, "run_shell_function", side_effect=capture_shell_run):
            with patch("subprocess.run"):
                from agentize.server.workers import _cleanup_refinement

                _cleanup_refinement(42)

        # Check that wt_claim_issue_status was called with Proposed
        status_called = any(
            "wt_claim_issue_status" in str(c) and "Proposed" in str(c)
            for c in captured_calls
        )
        assert status_called


class TestFeatRequestSpawnAndCleanup:
    """Tests for feat-request spawn and cleanup functions."""

    def test_spawn_feat_request_is_callable_with_model_param(self):
        """Test spawn_feat_request is callable and has model parameter."""
        import inspect
        from agentize.server.workers import spawn_feat_request

        assert callable(spawn_feat_request)

        sig = inspect.signature(spawn_feat_request)
        params = list(sig.parameters.keys())
        assert "model" in params
        assert sig.parameters["model"].default is None

    def test_spawn_feat_request_returns_false_on_failure(self):
        """Test spawn_feat_request returns (False, None) when wt spawn fails."""
        import agentize.server.workers as workers_module

        def mock_shell_run(cmd, **kwargs):
            if "wt pathto" in cmd:
                return MagicMock(returncode=1, stdout="")
            if "wt spawn" in cmd:
                return MagicMock(returncode=1, stdout="", stderr="error: spawn failed")
            return MagicMock(returncode=0, stdout="")

        with patch.object(workers_module, "run_shell_function", side_effect=mock_shell_run):
            success, pid = workers_module.spawn_feat_request(42)

        assert success is False
        assert pid is None

    def test_cleanup_feat_request_removes_dev_req_label(self, capsys):
        """Test _cleanup_feat_request removes agentize:dev-req label."""
        captured_calls = []

        def capture_run(*args, **kwargs):
            captured_calls.append(args[0] if args else kwargs.get("args", []))
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = ""
            return mock_result

        with patch("subprocess.run", side_effect=capture_run):
            import agentize.server.workers as workers_module

            with patch.object(
                workers_module,
                "run_shell_function",
                return_value=MagicMock(returncode=0, stdout="/tmp/test"),
            ):
                from agentize.server.workers import _cleanup_feat_request

                _cleanup_feat_request(42)

        # Check that gh issue edit was called with --remove-label agentize:dev-req
        edit_called = any(
            "--remove-label" in str(c) and "agentize:dev-req" in str(c)
            for c in captured_calls
        )
        assert edit_called

    def test_check_issue_has_label_for_dev_req(self):
        """Test _check_issue_has_label returns True for agentize:dev-req."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "agentize:dev-req\nbug\n"

        with patch("subprocess.run", return_value=mock_result):
            from agentize.server.workers import _check_issue_has_label

            result = _check_issue_has_label(42, "agentize:dev-req")

        assert result is True

    def test_cleanup_feat_request_sets_proposed_status(self, capsys):
        """Test _cleanup_feat_request calls wt_claim_issue_status with Proposed."""
        import agentize.server.workers as workers_module

        captured_calls = []

        def capture_shell_run(cmd, **kwargs):
            captured_calls.append(cmd)
            return MagicMock(returncode=0, stdout="/tmp/test-worktree")

        with patch.object(workers_module, "run_shell_function", side_effect=capture_shell_run):
            with patch("subprocess.run"):
                from agentize.server.workers import _cleanup_feat_request

                _cleanup_feat_request(42)

        # Check that wt_claim_issue_status was called with Proposed
        status_called = any(
            "wt_claim_issue_status" in str(c) and "Proposed" in str(c)
            for c in captured_calls
        )
        assert status_called
