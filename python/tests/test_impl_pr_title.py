"""Tests for PR title validation in impl workflow."""

import pytest
from agentize.workflow.impl.impl import _validate_pr_title, ImplError


def test_valid_title_with_feat_tag():
    """Valid title with [feat] tag should pass validation."""
    _validate_pr_title("[feat][#42] Add feature", 42)  # Should not raise


def test_valid_title_with_bugfix_tag():
    """Valid title with [bugfix] tag should pass validation."""
    _validate_pr_title("[bugfix][#15] Fix memory leak", 15)


def test_valid_title_with_docs_tag():
    """Valid title with [docs] tag should pass validation."""
    _validate_pr_title("[docs][#10] Update README", 10)


def test_valid_title_with_test_tag():
    """Valid title with [test] tag should pass validation."""
    _validate_pr_title("[test][#7] Add unit tests", 7)


def test_valid_title_with_refactor_tag():
    """Valid title with [refactor] tag should pass validation."""
    _validate_pr_title("[refactor][#3] Simplify logic", 3)


def test_valid_title_with_chore_tag():
    """Valid title with [chore] tag should pass validation."""
    _validate_pr_title("[chore][#1] Update dependencies", 1)


def test_valid_title_with_nested_agent_skill_tag():
    """Valid title with nested [agent.skill] tag should pass validation."""
    _validate_pr_title("[agent.skill][#1] Fix skill", 1)


def test_valid_title_with_nested_agent_command_tag():
    """Valid title with nested [agent.command] tag should pass validation."""
    _validate_pr_title("[agent.command][#5] Add new command", 5)


def test_valid_title_with_nested_agent_settings_tag():
    """Valid title with nested [agent.settings] tag should pass validation."""
    _validate_pr_title("[agent.settings][#8] Update config", 8)


def test_valid_title_with_nested_agent_workflow_tag():
    """Valid title with nested [agent.workflow] tag should pass validation."""
    _validate_pr_title("[agent.workflow][#12] Improve impl workflow", 12)


def test_valid_title_with_review_tag():
    """Valid title with [review] tag should pass validation."""
    _validate_pr_title("[review][#20] Address feedback", 20)


def test_valid_title_with_sdk_tag():
    """Valid title with [sdk] tag should pass validation."""
    _validate_pr_title("[sdk][#25] Update SDK template", 25)


def test_valid_title_with_cli_tag():
    """Valid title with [cli] tag should pass validation."""
    _validate_pr_title("[cli][#30] Add new flag", 30)


def test_valid_title_with_spaces_between_components():
    """Valid title with spaces between components should pass."""
    _validate_pr_title("[feat] [#42] Add feature", 42)


def test_missing_tag_raises_error():
    """Title without tag should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("Add feature", 42)


def test_missing_issue_number_raises_error():
    """Title without issue number should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[feat] Add feature", 42)


def test_empty_description_raises_error():
    """Title with empty description should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[feat][#42]", 42)


def test_only_whitespace_description_raises_error():
    """Title with only whitespace description should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[feat][#42]   ", 42)


def test_invalid_tag_raises_error():
    """Title with invalid tag should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[invalid][#42] Add feature", 42)


def test_incomplete_nested_tag_raises_error():
    """Title with incomplete nested tag should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[agent.unknown][#42] Add feature", 42)


def test_wrong_issue_number_format_raises_error():
    """Title with wrong issue number format should raise ImplError."""
    with pytest.raises(ImplError, match="doesn't match required format"):
        _validate_pr_title("[feat][42] Add feature", 42)
