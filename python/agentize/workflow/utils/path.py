"""Path helpers for workflow modules."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable


def relpath(from_file: str | Path, *parts: str | Path) -> Path:
    """Resolve an absolute path relative to the directory containing from_file."""
    base_dir = Path(from_file).resolve().parent
    if not parts:
        return base_dir

    candidate = Path(*parts)
    if candidate.is_absolute():
        return candidate
    return base_dir / candidate


__all__ = ["relpath"]
