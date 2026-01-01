# Test Fixture: git-add-with-milestones.json

## Purpose
Mock permission request for testing git add operations that include .milestones/ files in the Claude Code permission hook system.

## Expected Behavior
Permission hook should block staging .milestones/ files as these are local-only checkpoint files that should not be committed.
