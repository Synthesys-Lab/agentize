"""Prompt rendering helpers."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

_FRONTMATTER_RE = re.compile(r"^---\s*\n.*?\n---\s*\n", re.DOTALL)


def _strip_yaml_frontmatter(content: str) -> str:
    """Remove YAML frontmatter from markdown content."""
    return _FRONTMATTER_RE.sub("", content, count=1)


def read_prompt(path: str | Path, *, strip_frontmatter: bool = False) -> str:
    """Read a prompt file, optionally stripping YAML frontmatter."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Prompt file not found: {path}")
    content = path.read_text()
    if strip_frontmatter:
        return _strip_yaml_frontmatter(content)
    return content


def _replace_tokens(content: str, values: dict[str, Any]) -> str:
    rendered = content
    for key, value in values.items():
        token_value = "" if value is None else str(value)
        rendered = rendered.replace(f"{{{{{key}}}}}", token_value)
        rendered = rendered.replace(f"{{#{key}#}}", token_value)
    return rendered


def render(
    template_path: str | Path,
    values: dict[str, Any],
    dest_path: str | Path,
    *,
    strip_frontmatter: bool = False,
) -> str:
    """Render a template with replacements and write it to dest_path."""
    template = read_prompt(template_path, strip_frontmatter=strip_frontmatter)
    rendered = _replace_tokens(template, values)
    dest_path = Path(dest_path)
    dest_path.write_text(rendered)
    return rendered


__all__ = ["read_prompt", "render"]
