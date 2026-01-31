# session.py

Session state file lookups for server notifications and workflow tracking.

## External Interface

### set_pr_number_for_issue(issue_no: int, pr_number: int, session_dir: Optional[Path] = None) -> bool

Persist the PR number into the session state for a given issue.

**Parameters:**
- `issue_no`: GitHub issue number.
- `pr_number`: PR number to store in the session state.
- `session_dir`: Optional override for the hooked-sessions directory.

**Returns:**
- `True` when the session state was updated successfully.
- `False` if the issue index or session file is missing, or on I/O errors.

## Internal Helpers

### _resolve_session_dir(base_dir: Optional[str] = None) -> Path

Resolve the hooked-sessions directory from `AGENTIZE_HOME` (or `base_dir` when provided).

### _load_issue_index(issue_no: int, session_dir: Path) -> Optional[str]

Read `by-issue/<issue_no>.json` and return the stored `session_id` when present.

### _load_session_state(session_id: str, session_dir: Path) -> Optional[dict]

Load the JSON session state file and return its contents.

### _get_session_state_for_issue(issue_no: int, session_dir: Path) -> Optional[dict]

Convenience wrapper that resolves `session_id` and then loads the session state.

### _remove_issue_index(issue_no: int, session_dir: Path) -> None

Remove the issue index file after notifications are sent (best-effort cleanup).

## Design Notes

- Session files live under `.tmp/hooked-sessions` and are indexed by issue.
- All file operations are best-effort: malformed JSON or missing files return `None`.
- `set_pr_number_for_issue` writes atomically using a temporary file and rename.
