# Permission Request Hook Fixtures

This directory contains test fixtures for the Claude Code permission request hook (`permission-request.sh`).

## CLAUDE_HANDSOFF Environment Variable

The permission hook uses `CLAUDE_HANDSOFF` as the primary configuration method for hands-off mode.

### Expected Behavior

- `CLAUDE_HANDSOFF=true` (case-insensitive) → Safe local workflow operations are auto-allowed
- `CLAUDE_HANDSOFF=false` (case-insensitive) → Always ask for permission
- `CLAUDE_HANDSOFF=<invalid>` → Treat as disabled (always ask)
- Unset → Always ask for permission (fail-closed)

### Auto-Approved Operations (when CLAUDE_HANDSOFF=true)

**File operations:**
- Read, Edit, Write, Glob, Grep

**Safe git commands:**
- git status, git diff, git log, git show, git rev-parse
- git checkout, git switch, git branch
- git add, git commit
- git fetch, git rebase

**Test/build commands:**
- make test, make build, make check, make lint
- npm test, pytest
- Test scripts in tests/

**GitHub read operations:**
- gh issue view, gh pr view, gh pr list, gh issue list
- gh search, gh run view, gh run list

### Operations That Still Require Approval

**Publish operations:**
- git push
- gh pr create, gh issue create

**Destructive operations:**
- rm -rf, git clean
- git reset --hard
- git push --force

### Test Cases

1. **Enabled hands-off**: `CLAUDE_HANDSOFF=true` + safe read → `allow`
2. **Disabled hands-off**: `CLAUDE_HANDSOFF=false` + safe read → `ask`
3. **Invalid value**: `CLAUDE_HANDSOFF=maybe` + safe read → `ask` (fail-closed)
4. **Unset variable**: Unset env var + safe read → `ask` (fail-closed)
5. **Destructive protection**: `CLAUDE_HANDSOFF=true` + destructive bash → `deny` or `ask`
6. **Edit auto-allow**: `CLAUDE_HANDSOFF=true` + Edit → `allow`
7. **Write auto-allow**: `CLAUDE_HANDSOFF=true` + Write → `allow`
8. **Safe git auto-allow**: `CLAUDE_HANDSOFF=true` + git status → `allow`
9. **Git commit auto-allow**: `CLAUDE_HANDSOFF=true` + git commit → `allow`
10. **Git push gated**: `CLAUDE_HANDSOFF=true` + git push → `ask` or `deny`
11. **PR create gated**: `CLAUDE_HANDSOFF=true` + gh pr create → `ask` or `deny`
12. **Test command auto-allow**: `CLAUDE_HANDSOFF=true` + make test → `allow`
13. **Disabled mode Edit**: `CLAUDE_HANDSOFF=false` + Edit → `ask`
