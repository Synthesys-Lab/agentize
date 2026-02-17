"""Checkpoint save/restore for the lol impl workflow."""

from __future__ import annotations

import json
import tempfile
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

CHECKPOINT_VERSION = 2


@dataclass
class ImplState:
    """Serializable workflow state for checkpointing."""

    issue_no: int
    current_stage: Literal["impl", "review", "simp", "pr", "rebase", "fatal", "done"]
    iteration: int
    worktree: Path
    plan_file: Path | None
    last_feedback: str
    last_score: int
    history: list[dict]
    pr_number: str | None = None
    pr_url: str | None = None

    def to_dict(self) -> dict:
        """Convert state to dictionary for serialization."""
        return {
            "issue_no": self.issue_no,
            "current_stage": self.current_stage,
            "iteration": self.iteration,
            "worktree": str(self.worktree),
            "plan_file": str(self.plan_file) if self.plan_file else None,
            "last_feedback": self.last_feedback,
            "last_score": self.last_score,
            "history": self.history,
            "pr_number": self.pr_number,
            "pr_url": self.pr_url,
        }

    @classmethod
    def from_dict(cls, data: dict) -> ImplState:
        """Create state from dictionary."""
        return cls(
            issue_no=data["issue_no"],
            current_stage=data["current_stage"],
            iteration=data["iteration"],
            worktree=Path(data["worktree"]),
            plan_file=Path(data["plan_file"]) if data.get("plan_file") else None,
            last_feedback=data.get("last_feedback", ""),
            last_score=data.get("last_score", 0),
            history=data.get("history", []),
            pr_number=data.get("pr_number"),
            pr_url=data.get("pr_url"),
        )

    def save(self, path: Path) -> None:
        """Save state to checkpoint file."""
        save_checkpoint(self, path)

    @classmethod
    def load(cls, path: Path) -> ImplState:
        """Load state from checkpoint file."""
        return load_checkpoint(path)


def save_checkpoint(state: ImplState, checkpoint_path: Path) -> None:
    """Save state to a checkpoint file.

    Args:
        state: The state to save.
        checkpoint_path: Path to write the checkpoint file.

    Raises:
        ImplError: If serialization fails.
        OSError: For filesystem errors.
    """
    from agentize.workflow.impl.impl import ImplError

    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)

    checkpoint_data = {
        "version": CHECKPOINT_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "state": state.to_dict(),
    }

    try:
        # Atomic write: write to temp file, then rename
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".json",
            dir=checkpoint_path.parent,
            delete=False,
        ) as f:
            json.dump(checkpoint_data, f, indent=2)
            temp_path = Path(f.name)

        temp_path.rename(checkpoint_path)
    except (TypeError, ValueError) as exc:
        raise ImplError(f"Failed to serialize checkpoint: {exc}") from exc


def load_checkpoint(checkpoint_path: Path) -> ImplState:
    """Load state from a checkpoint file.

    Args:
        checkpoint_path: Path to the checkpoint file.

    Returns:
        The loaded ImplState object.

    Raises:
        ImplError: If file doesn't exist, is corrupted, or version is incompatible.
    """
    from agentize.workflow.impl.impl import ImplError

    if not checkpoint_path.exists():
        raise ImplError(f"Checkpoint file not found: {checkpoint_path}")

    try:
        with open(checkpoint_path, "r") as f:
            checkpoint_data = json.load(f)
    except json.JSONDecodeError as exc:
        raise ImplError(f"Corrupted checkpoint file: {exc}") from exc
    except OSError as exc:
        raise ImplError(f"Failed to read checkpoint file: {exc}") from exc

    version = checkpoint_data.get("version", 0)
    if version != CHECKPOINT_VERSION:
        raise ImplError(
            f"Checkpoint version mismatch: expected {CHECKPOINT_VERSION}, got {version}"
        )

    try:
        state = ImplState.from_dict(checkpoint_data["state"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ImplError(f"Invalid checkpoint data: {exc}") from exc

    return state


def checkpoint_exists(checkpoint_path: Path) -> bool:
    """Check if a valid checkpoint file exists.

    Args:
        checkpoint_path: Path to check.

    Returns:
        True if checkpoint exists and is readable.
    """
    if not checkpoint_path.exists():
        return False

    try:
        with open(checkpoint_path, "r") as f:
            checkpoint_data = json.load(f)
        return checkpoint_data.get("version") == CHECKPOINT_VERSION
    except (json.JSONDecodeError, OSError):
        return False


def create_initial_state(
    issue_no: int,
    worktree: Path,
    plan_file: Path | None = None,
) -> ImplState:
    """Create initial state for a new workflow.

    Args:
        issue_no: The GitHub issue number.
        worktree: Path to the git worktree.
        plan_file: Optional path to the implementation plan.

    Returns:
        Initial ImplState with default values.
    """
    return ImplState(
        issue_no=issue_no,
        current_stage="impl",
        iteration=1,
        worktree=worktree,
        plan_file=plan_file,
        last_feedback="",
        last_score=0,
        history=[],
    )
