# Permission Request Test Fixtures

This directory contains JSON fixtures for testing the PermissionRequest hook (`.claude/hooks/permission-request.sh`).

## Purpose

Each JSON file represents a simulated tool permission request that Claude Code would send to the PermissionRequest hook. The test harness (`tests/test-claude-permission-hook.sh`) uses these fixtures to validate that the hook correctly approves safe operations and blocks destructive ones.

## Fixture Format

Each fixture is a JSON object with the structure:
```json
{
  "tool": "ToolName",
  "parameters": {
    "param1": "value1",
    ...
  }
}
```

## Available Fixtures

### safe-read.json
**Tool**: Read
**Purpose**: Tests that read-only operations are auto-approved when hands-off mode is enabled
**Expected**: `allow` when enabled, `ask` when disabled

### reversible-write.json
**Tool**: Write
**Purpose**: Tests that file writes are auto-approved on non-main branches
**Expected**: `allow` on issue branches when enabled, `ask` on main or when disabled

### destructive-push.json
**Tool**: Bash (git push)
**Purpose**: Tests that git push commands are blocked
**Expected**: `deny` or `ask` (never `allow`)

### git-reset-hard.json
**Tool**: Bash (git reset --hard)
**Purpose**: Tests that destructive git commands are blocked
**Expected**: `deny` or `ask` (never `allow`)

### git-add-with-milestones.json
**Tool**: Bash (git add -A)
**Purpose**: Tests the .milestones/ staging guard
**Expected**: Special handling when .milestones/ files are present

## Usage

These fixtures are consumed by `tests/test-claude-permission-hook.sh`:

```bash
# Run hook with fixture
./claude/hooks/permission-request.sh < tests/fixtures/permission-request/safe-read.json

# Expected output format
{"decision": "allow"}
{"decision": "deny"}
{"decision": "ask"}
```

## Adding New Fixtures

To add a new test scenario:

1. Create a new JSON file following the format above
2. Add corresponding test case in `tests/test-claude-permission-hook.sh`
3. Document the fixture in this README
