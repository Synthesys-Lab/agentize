# Milestone Resume Hint Helper

Helper script for displaying milestone resume hints at session start when hands-off mode is enabled.

## External Interface

### Entry Point

```bash
bash .claude/hooks/milestone-resume-hint.sh
```

### Environment Variables

**Input:**
- `CLAUDE_HANDSOFF`: Controls hint display
  - `true`, `1`, `yes`: Enable hint display
  - Any other value or unset: Disable hint display (fail-closed)

**Output:**
- Stdout: Formatted hint message (when conditions met)
- Stderr: None (all errors suppressed)

### Exit Codes

- `0`: Always returns success (fail-safe design)
  - Hint displayed successfully
  - OR conditions not met (no hint displayed)
  - OR error occurred (silently suppressed)

### Preconditions for Hint Display

All conditions must be met:
1. `CLAUDE_HANDSOFF` is `true`, `1`, or `yes`
2. Current directory is a git repository
3. Current branch matches pattern `issue-{N}-*` where N is an integer
4. `.milestones/` directory exists
5. At least one milestone file exists matching `issue-{N}-milestone-*.md`

If any condition fails, script exits silently with status 0.

## Internal Helpers

### is_handsoff_enabled()

Checks if hands-off mode is enabled using strict boolean validation.

**Parameters**: None (reads `CLAUDE_HANDSOFF` environment variable)

**Returns**:
- `0`: Hands-off mode enabled (`true`, `1`, or `yes`)
- `1`: Hands-off mode disabled (any other value or unset)

**Design**: Fail-closed approach - only explicit true values enable the hint.

### extract_issue_number()

Extracts issue number from branch name.

**Parameters**:
- `$1`: Branch name (e.g., `issue-42-add-feature`)

**Returns**:
- `0`: Issue number successfully extracted
- `1`: Branch name doesn't match pattern

**Output** (stdout): Issue number (e.g., `42`)

**Pattern**: `^issue-([0-9]+)-` using bash regex matching

### find_latest_milestone()

Finds the most recent milestone file for a given issue.

**Parameters**:
- `$1`: Issue number (e.g., `42`)

**Returns**:
- `0`: Milestone file found
- `1`: No milestone files found or `.milestones/` directory missing

**Output** (stdout): Full path to latest milestone file (e.g., `.milestones/issue-42-milestone-3.md`)

**Algorithm**:
1. List all files matching `.milestones/issue-{N}-milestone-*.md`
2. Sort using `sort -V` (version sort) to handle multi-digit milestone numbers correctly
   - Example: milestone-2, milestone-10, milestone-11 (not milestone-10, milestone-11, milestone-2)
3. Select last file with `tail -n 1`

**Rationale for sort -V**: Version sort ensures correct ordering when milestone numbers exceed 9:
- Numeric sort would fail: milestone-10 < milestone-2 (string comparison)
- Version sort succeeds: milestone-2 < milestone-10 < milestone-11

### extract_milestone_number()

Extracts milestone number from milestone file path.

**Parameters**:
- `$1`: Milestone file path (e.g., `.milestones/issue-42-milestone-3.md`)

**Returns**:
- `0`: Milestone number successfully extracted
- `1`: File path doesn't match expected pattern

**Output** (stdout): Milestone number (e.g., `3`)

**Pattern**: `milestone-([0-9]+)\.md$` using bash regex matching

## Output Format

When all preconditions are met, displays:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Milestone Resume Hint
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Branch: {branch-name}
  Latest milestone: {milestone-path}

  To resume implementation:
    "Continue from the latest milestone"
    "Resume implementation"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Design notes**:
- Clear visual separation with box borders
- Concise information (branch and milestone path)
- Multiple natural-language resume examples for flexibility
- No error messages or warnings (fail-silent design)

## Error Handling

### Philosophy: Fail Silent, Fail Safe

The script never interrupts the user session. All error conditions result in:
- Silent exit (no output)
- Status code 0 (success)
- No side effects

### Error Scenarios

**Scenario**: Not in git repository
- **Detection**: `git rev-parse --is-inside-work-tree` fails
- **Action**: Exit silently with status 0

**Scenario**: Current branch unavailable
- **Detection**: `git branch --show-current` returns empty
- **Action**: Exit silently with status 0

**Scenario**: Branch doesn't match issue pattern
- **Detection**: `extract_issue_number()` returns 1
- **Action**: Exit silently with status 0

**Scenario**: No milestones directory
- **Detection**: `[ ! -d .milestones ]` is true
- **Action**: Exit silently with status 0

**Scenario**: No milestone files found
- **Detection**: `find_latest_milestone()` returns 1
- **Action**: Exit silently with status 0

**Rationale**: This is a convenience feature (automated hint display). It should never block or confuse the user with error messages. If conditions aren't met, simply don't show the hint.

## Testing

Comprehensive test coverage in `tests/test-milestone-resume-hint.sh`:

1. **CLAUDE_HANDSOFF=true with milestone**: Hint displayed
2. **CLAUDE_HANDSOFF=false**: No hint displayed
3. **CLAUDE_HANDSOFF unset**: No hint displayed (fail-closed)
4. **Non-issue branch**: No hint displayed
5. **Multiple milestones**: Latest selected correctly (version sort validation)
6. **Invalid CLAUDE_HANDSOFF value**: No hint displayed (fail-closed)
7. **No milestone files**: No hint displayed

All tests use temporary git repositories for isolation.

## Integration

Invoked by `.claude/hooks/session-init.sh`:

```bash
# Show milestone resume hint if applicable
if [ -f "$SCRIPT_DIR/milestone-resume-hint.sh" ]; then
    bash "$SCRIPT_DIR/milestone-resume-hint.sh"
fi
```

The session-init hook checks for existence before invoking, allowing the feature to be disabled by removing the script file.
