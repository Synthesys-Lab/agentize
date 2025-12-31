# Permission Request Hook Fixtures

This directory contains test fixtures for the Claude Code permission request hook (`permission-request.sh`).

## CLAUDE_HANDSOFF Environment Variable

The permission hook uses `CLAUDE_HANDSOFF` as the primary configuration method for hands-off mode.

### Expected Behavior

- `CLAUDE_HANDSOFF=true` (case-insensitive) → Safe read operations are auto-allowed
- `CLAUDE_HANDSOFF=false` (case-insensitive) → Always ask for permission
- `CLAUDE_HANDSOFF=<invalid>` → Treat as disabled (always ask)
- Unset → Always ask for permission (fail-closed)

### Test Cases

1. **Enabled hands-off**: `CLAUDE_HANDSOFF=true` + safe read → `allow`
2. **Disabled hands-off**: `CLAUDE_HANDSOFF=false` + safe read → `ask`
3. **Invalid value**: `CLAUDE_HANDSOFF=maybe` + safe read → `ask` (fail-closed)
4. **Unset variable**: Unset env var + safe read → `ask` (fail-closed)
5. **Destructive protection**: `CLAUDE_HANDSOFF=true` + destructive bash → `deny` or `ask`
