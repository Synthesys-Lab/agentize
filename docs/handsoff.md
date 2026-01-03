# Hands-Off Mode

Enable automated workflows without manual permission prompts by setting `CLAUDE_HANDSOFF=true`. This mode auto-approves safe, local operations while maintaining strict safety boundaries for destructive or publish actions.

## Quick Start

```bash
# Enable hands-off mode
export CLAUDE_HANDSOFF=true

# Run full implementation workflow without prompts
/issue-to-impl 42
```

## What Gets Auto-Approved

When `CLAUDE_HANDSOFF=true`, the following operations proceed without permission prompts:

### File Operations
- **Read**: All file read operations
- **Write**: Create new files
- **Edit**: Modify existing files
- **Glob**: File pattern matching
- **Grep**: Content search

### Safe Git Commands
- **Status/Info**: `git status`, `git diff`, `git log`, `git show`, `git rev-parse`
- **Local branching**: `git checkout`, `git switch`, `git branch`
- **Staging**: `git add`
- **Committing**: `git commit` (local only, no push)
- **Sync operations**: `git fetch`, `git rebase` (for branch sync)

### Test/Build Commands
- **Test runners**: `make test`, `make check`, `npm test`, `pytest`, test scripts in `tests/`
- **Build commands**: `make build`, `make all`, `ninja`, `cmake`
- **Linters**: `make lint`

### GitHub Read Operations
- **View commands**: `gh issue view`, `gh pr view`, `gh pr list`, `gh issue list`
- **Search**: `gh search`
- **Run info**: `gh run view`, `gh run list`

## What Still Requires Approval

Hands-off mode **does NOT** auto-approve:

### Destructive Operations
- `rm -rf`, `git clean`
- `git reset --hard`
- `git push --force`

### Publish Operations
- `git push` (publishing to remote)
- `gh pr create` (creating pull requests)
- `gh issue create` (creating issues)

### Administrative Commands
- Package installation (`npm install`, `pip install`)
- Permission changes (`chmod`, `chown`)
- System configuration

## Workflow Examples

### Full Implementation Workflow

```bash
# Enable hands-off mode
export CLAUDE_HANDSOFF=true

# Start implementation from issue
/issue-to-impl 42

# This auto-approves:
# - Creating branch (git checkout -b)
# - Writing docs (Write tool)
# - Creating tests (Write tool)
# - Implementing code (Edit/Write tools)
# - Running tests (make test)
# - Creating milestone commits (git add/commit)

# Resume from milestone
User: Continue from the latest milestone

# Review changes (still auto-approved for reads)
/code-review

# This STILL REQUIRES APPROVAL:
/open-pr  # Publishing PR requires manual confirmation
```

### Planning Workflow

```bash
export CLAUDE_HANDSOFF=true

# Auto-approves exploration and planning
/ultra-planner "implement user authentication"

# Auto-approves reading issue, creating plan
/refine-issue 42
```

## Safety Boundaries

Hands-off mode is designed for **local development workflows** on feature branches. Safety is maintained through:

1. **Fail-closed default**: Unknown tools/commands default to asking for permission
2. **Branch restrictions**: Most workflows operate on feature branches (e.g., `issue-42-*`)
3. **No publish auto-approval**: Remote operations (push, PR creation) always require confirmation
4. **Explicit denylists**: Destructive commands are explicitly blocked from auto-approval

## Disabling Hands-Off Mode

```bash
# Disable hands-off mode (back to interactive)
export CLAUDE_HANDSOFF=false

# Or unset the variable
unset CLAUDE_HANDSOFF
```

When disabled or unset, all operations require permission prompts (original behavior).

## Troubleshooting

### Stuck Workflow

If a workflow gets stuck waiting for permission:

1. Check `CLAUDE_HANDSOFF` value:
   ```bash
   echo $CLAUDE_HANDSOFF
   ```

2. Verify the operation is in the auto-approve list above

3. Check hook logs (if logging is enabled):
   ```bash
   cat .tmp/claude-hooks/auto-approvals.log
   ```

### Force Manual Mode

To force manual approval for a specific command while hands-off mode is enabled:

```bash
CLAUDE_HANDSOFF=false /issue-to-impl 42
```

## Implementation Details

The permission hook (`.claude/hooks/permission-request.sh`) inspects:
- `CLAUDE_HANDSOFF` environment variable
- Tool name being invoked
- Tool parameters (for Bash commands)

Based on these inputs, it returns:
- `allow` for safe, local operations when `CLAUDE_HANDSOFF=true`
- `ask` for destructive/publish operations or when hands-off mode is disabled
- `deny` for explicitly blocked operations

See `.claude/hooks/permission-request.sh` for implementation details.

## Related Documentation

- [Issue to Implementation Workflow](workflows/issue-to-implementation.md)
- [Issue-to-Impl Tutorial](tutorial/02-issue-to-impl.md)
- [Ultra Planner Workflow](workflows/ultra-planner.md)
