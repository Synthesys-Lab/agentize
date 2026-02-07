"""Tests for checkpoint save/restore functionality."""

import json
from pathlib import Path

import pytest

from agentize.workflow.impl.checkpoint import (
    CHECKPOINT_VERSION,
    ImplState,
    checkpoint_exists,
    create_initial_state,
    load_checkpoint,
    save_checkpoint,
)
from agentize.workflow.impl.impl import ImplError


class TestImplState:
    """Tests for ImplState dataclass."""

    def test_to_dict_converts_paths_to_strings(self, tmp_path: Path):
        """Test that to_dict converts Path objects to strings."""
        state = ImplState(
            issue_no=42,
            current_stage="impl",
            iteration=3,
            worktree=tmp_path / "worktree",
            plan_file=tmp_path / "plan.md",
            last_feedback="Test feedback",
            last_score=85,
            history=[{"stage": "impl", "result": "success"}],
        )

        data = state.to_dict()

        assert data["issue_no"] == 42
        assert data["current_stage"] == "impl"
        assert data["iteration"] == 3
        assert data["worktree"] == str(tmp_path / "worktree")
        assert data["plan_file"] == str(tmp_path / "plan.md")
        assert data["last_feedback"] == "Test feedback"
        assert data["last_score"] == 85
        assert data["history"] == [{"stage": "impl", "result": "success"}]

    def test_to_dict_handles_none_plan_file(self, tmp_path: Path):
        """Test that to_dict handles None plan_file."""
        state = ImplState(
            issue_no=42,
            current_stage="impl",
            iteration=1,
            worktree=tmp_path,
            plan_file=None,
            last_feedback="",
            last_score=0,
            history=[],
        )

        data = state.to_dict()

        assert data["plan_file"] is None

    def test_from_dict_reconstructs_paths(self, tmp_path: Path):
        """Test that from_dict reconstructs Path objects."""
        data = {
            "issue_no": 42,
            "current_stage": "review",
            "iteration": 2,
            "worktree": str(tmp_path / "worktree"),
            "plan_file": str(tmp_path / "plan.md"),
            "last_feedback": "Feedback text",
            "last_score": 75,
            "history": [],
        }

        state = ImplState.from_dict(data)

        assert state.issue_no == 42
        assert state.current_stage == "review"
        assert state.iteration == 2
        assert state.worktree == tmp_path / "worktree"
        assert isinstance(state.worktree, Path)
        assert state.plan_file == tmp_path / "plan.md"
        assert isinstance(state.plan_file, Path)
        assert state.last_feedback == "Feedback text"
        assert state.last_score == 75

    def test_from_dict_handles_none_plan_file(self, tmp_path: Path):
        """Test that from_dict handles None plan_file."""
        data = {
            "issue_no": 42,
            "current_stage": "impl",
            "iteration": 1,
            "worktree": str(tmp_path),
            "plan_file": None,
            "last_feedback": "",
            "last_score": 0,
            "history": [],
        }

        state = ImplState.from_dict(data)

        assert state.plan_file is None

    def test_from_dict_uses_defaults_for_missing_optional_fields(self, tmp_path: Path):
        """Test that from_dict uses defaults for missing optional fields."""
        data = {
            "issue_no": 42,
            "current_stage": "impl",
            "iteration": 1,
            "worktree": str(tmp_path),
            "plan_file": None,
        }

        state = ImplState.from_dict(data)

        assert state.last_feedback == ""
        assert state.last_score == 0
        assert state.history == []


class TestSaveCheckpoint:
    """Tests for save_checkpoint function."""

    def test_save_creates_checkpoint_file(self, tmp_path: Path):
        """Test that save_checkpoint creates a checkpoint file."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"

        save_checkpoint(state, checkpoint_path)

        assert checkpoint_path.exists()

    def test_save_creates_parent_directories(self, tmp_path: Path):
        """Test that save_checkpoint creates parent directories."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "nested" / "deep" / "checkpoint.json"

        save_checkpoint(state, checkpoint_path)

        assert checkpoint_path.exists()

    def test_save_writes_valid_json(self, tmp_path: Path):
        """Test that save_checkpoint writes valid JSON."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"

        save_checkpoint(state, checkpoint_path)

        with open(checkpoint_path) as f:
            data = json.load(f)

        assert "version" in data
        assert "timestamp" in data
        assert "state" in data

    def test_save_includes_version(self, tmp_path: Path):
        """Test that save_checkpoint includes version field."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"

        save_checkpoint(state, checkpoint_path)

        with open(checkpoint_path) as f:
            data = json.load(f)

        assert data["version"] == CHECKPOINT_VERSION

    def test_save_is_atomic(self, tmp_path: Path):
        """Test that save_checkpoint uses atomic write."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"

        save_checkpoint(state, checkpoint_path)

        # Should not leave temp files
        temp_files = list(tmp_path.glob("*.tmp"))
        assert len(temp_files) == 0


class TestLoadCheckpoint:
    """Tests for load_checkpoint function."""

    def test_load_restores_state(self, tmp_path: Path):
        """Test that load_checkpoint restores the saved state."""
        original_state = ImplState(
            issue_no=42,
            current_stage="review",
            iteration=3,
            worktree=tmp_path / "worktree",
            plan_file=tmp_path / "plan.md",
            last_feedback="Test feedback",
            last_score=85,
            history=[{"stage": "impl", "iteration": 1, "result": "success"}],
        )
        checkpoint_path = tmp_path / "checkpoint.json"
        save_checkpoint(original_state, checkpoint_path)

        loaded_state = load_checkpoint(checkpoint_path)

        assert loaded_state.issue_no == original_state.issue_no
        assert loaded_state.current_stage == original_state.current_stage
        assert loaded_state.iteration == original_state.iteration
        assert loaded_state.worktree == original_state.worktree
        assert loaded_state.plan_file == original_state.plan_file
        assert loaded_state.last_feedback == original_state.last_feedback
        assert loaded_state.last_score == original_state.last_score
        assert loaded_state.history == original_state.history

    def test_load_raises_error_for_missing_file(self, tmp_path: Path):
        """Test that load_checkpoint raises error for missing file."""
        checkpoint_path = tmp_path / "nonexistent.json"

        with pytest.raises(ImplError, match="Checkpoint file not found"):
            load_checkpoint(checkpoint_path)

    def test_load_raises_error_for_corrupted_json(self, tmp_path: Path):
        """Test that load_checkpoint raises error for corrupted JSON."""
        checkpoint_path = tmp_path / "checkpoint.json"
        checkpoint_path.write_text("not valid json")

        with pytest.raises(ImplError, match="Corrupted checkpoint file"):
            load_checkpoint(checkpoint_path)

    def test_load_raises_error_for_version_mismatch(self, tmp_path: Path):
        """Test that load_checkpoint raises error for version mismatch."""
        checkpoint_path = tmp_path / "checkpoint.json"
        checkpoint_data = {
            "version": 999,
            "timestamp": "2025-01-15T10:00:00",
            "state": {},
        }
        with open(checkpoint_path, "w") as f:
            json.dump(checkpoint_data, f)

        with pytest.raises(ImplError, match="version mismatch"):
            load_checkpoint(checkpoint_path)

    def test_load_raises_error_for_invalid_state_data(self, tmp_path: Path):
        """Test that load_checkpoint raises error for invalid state data."""
        checkpoint_path = tmp_path / "checkpoint.json"
        checkpoint_data = {
            "version": CHECKPOINT_VERSION,
            "timestamp": "2025-01-15T10:00:00",
            "state": {"invalid": "data"},
        }
        with open(checkpoint_path, "w") as f:
            json.dump(checkpoint_data, f)

        with pytest.raises(ImplError, match="Invalid checkpoint data"):
            load_checkpoint(checkpoint_path)


class TestCheckpointExists:
    """Tests for checkpoint_exists function."""

    def test_returns_false_for_missing_file(self, tmp_path: Path):
        """Test that checkpoint_exists returns False for missing file."""
        checkpoint_path = tmp_path / "nonexistent.json"

        assert checkpoint_exists(checkpoint_path) is False

    def test_returns_true_for_valid_checkpoint(self, tmp_path: Path):
        """Test that checkpoint_exists returns True for valid checkpoint."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"
        save_checkpoint(state, checkpoint_path)

        assert checkpoint_exists(checkpoint_path) is True

    def test_returns_false_for_corrupted_file(self, tmp_path: Path):
        """Test that checkpoint_exists returns False for corrupted file."""
        checkpoint_path = tmp_path / "checkpoint.json"
        checkpoint_path.write_text("not valid json")

        assert checkpoint_exists(checkpoint_path) is False

    def test_returns_false_for_wrong_version(self, tmp_path: Path):
        """Test that checkpoint_exists returns False for wrong version."""
        checkpoint_path = tmp_path / "checkpoint.json"
        checkpoint_data = {
            "version": 999,
            "timestamp": "2025-01-15T10:00:00",
            "state": {},
        }
        with open(checkpoint_path, "w") as f:
            json.dump(checkpoint_data, f)

        assert checkpoint_exists(checkpoint_path) is False


class TestCreateInitialState:
    """Tests for create_initial_state function."""

    def test_creates_state_with_defaults(self, tmp_path: Path):
        """Test that create_initial_state creates state with default values."""
        state = create_initial_state(42, tmp_path)

        assert state.issue_no == 42
        assert state.current_stage == "impl"
        assert state.iteration == 1
        assert state.worktree == tmp_path
        assert state.plan_file is None
        assert state.last_feedback == ""
        assert state.last_score == 0
        assert state.history == []

    def test_creates_state_with_plan_file(self, tmp_path: Path):
        """Test that create_initial_state creates state with plan file."""
        plan_path = tmp_path / "plan.md"
        state = create_initial_state(42, tmp_path, plan_path)

        assert state.plan_file == plan_path


class TestImplStateSaveLoad:
    """Tests for ImplState.save() and ImplState.load() methods."""

    def test_save_method_delegates_to_save_checkpoint(self, tmp_path: Path):
        """Test that ImplState.save() delegates to save_checkpoint."""
        state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"

        state.save(checkpoint_path)

        assert checkpoint_path.exists()

    def test_load_method_delegates_to_load_checkpoint(self, tmp_path: Path):
        """Test that ImplState.load() delegates to load_checkpoint."""
        original_state = create_initial_state(42, tmp_path)
        checkpoint_path = tmp_path / "checkpoint.json"
        original_state.save(checkpoint_path)

        loaded_state = ImplState.load(checkpoint_path)

        assert loaded_state.issue_no == original_state.issue_no


class TestRoundTrip:
    """Tests for save/load round-trip."""

    def test_complex_state_round_trip(self, tmp_path: Path):
        """Test that complex state survives round-trip."""
        complex_feedback = """
        Implementation review feedback:
        - Code quality is good
        - Tests are missing edge cases
        - Documentation needs improvement
        
        Score: 75/100
        """
        original_state = ImplState(
            issue_no=123,
            current_stage="review",
            iteration=5,
            worktree=tmp_path / "issues" / "123",
            plan_file=tmp_path / "plans" / "123.md",
            last_feedback=complex_feedback,
            last_score=75,
            history=[
                {
                    "stage": "impl",
                    "iteration": 1,
                    "timestamp": "2025-01-15T10:00:00",
                    "result": "success",
                    "score": None,
                },
                {
                    "stage": "review",
                    "iteration": 1,
                    "timestamp": "2025-01-15T10:15:00",
                    "result": "retry",
                    "score": 60,
                },
                {
                    "stage": "impl",
                    "iteration": 2,
                    "timestamp": "2025-01-15T10:30:00",
                    "result": "success",
                    "score": None,
                },
            ],
        )
        checkpoint_path = tmp_path / "checkpoint.json"

        save_checkpoint(original_state, checkpoint_path)
        loaded_state = load_checkpoint(checkpoint_path)

        assert loaded_state.issue_no == original_state.issue_no
        assert loaded_state.current_stage == original_state.current_stage
        assert loaded_state.iteration == original_state.iteration
        assert loaded_state.worktree == original_state.worktree
        assert loaded_state.plan_file == original_state.plan_file
        assert loaded_state.last_feedback == original_state.last_feedback
        assert loaded_state.last_score == original_state.last_score
        assert len(loaded_state.history) == len(original_state.history)
        for i, entry in enumerate(loaded_state.history):
            assert entry == original_state.history[i]
