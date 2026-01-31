# Post Bash Issue Create Hook

Captures issue numbers from `gh issue create` commands during Ultra Planner workflows and stores them in the session state.

## External Interface

### Hook invocation

- **Input (stdin):** JSON object with `tool_name`, `tool_input`, and `tool_response` fields.
- **Output (stdout):** None (exits silently unless a session update occurs).
- **Exit behavior:** Always exits 0; returns early when inputs do not match expected conditions.

### Behavior

- Only processes the `Bash` tool.
- Only responds to commands containing `gh issue create`.
- Extracts the issue number from the command output URL.
- Updates the session state only when:
  - The session file exists.
  - The workflow is `ULTRA_PLANNER`.
  - `issue_no` is not already set.
- Writes a `by-issue/<issue_no>.json` index for reverse lookup.

## Internal Helpers

### `_extract_issue_number_from_output(output: str) -> Optional[int]`

Parses the first matching GitHub issue URL from output text and returns the issue number as an integer. Returns `None` when no URL match is found.

## Design Rationale

**Workflow-scoped capture:** Restricting updates to the Ultra Planner workflow prevents unintended session mutation during unrelated CLI usage.

**Idempotent update:** Skipping when `issue_no` is already set avoids clobbering the session state if multiple hooks fire.

**Side-effect isolation:** The hook exits silently for non-matching inputs to avoid noise in hook pipelines.

## Internal Usage

- `.claude-plugin/hooks/post-bash-issue-create.py`: Implements the hook logic.
