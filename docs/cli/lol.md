# lol CLI

The `lol` command provides SDK initialization, project management, and automation server capabilities.

## Entrypoints

**Shell (canonical):**
```bash
source setup.sh  # Sources src/cli/lol.sh
lol <command> [options]
```

**Python (optional):**
```bash
python -m agentize.cli <command> [options]
```

The Python entrypoint delegates to shell functions via `bash -lc` with `AGENTIZE_HOME` set. Use it for non-sourced environments or scripting contexts where argparse-style parsing is preferred.

## Commands

### lol init

Initialize a new SDK project.

```bash
lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]
```

### lol update

Update an existing project with the latest agentize configurations.

```bash
lol update [--path <path>]
```

### lol upgrade

Upgrade the agentize installation.

```bash
lol upgrade
```

### lol project

Manage GitHub Projects v2 integration.

```bash
lol project --create [--org <org>] [--title <title>]
lol project --associate <org>/<id>
lol project --automation [--write <path>]
```

See [Project Management](../architecture/project.md) for details.

### lol claude-clean

Remove stale project entries from Claude's global configuration file (`~/.claude.json`).

```bash
lol claude-clean [--dry-run]
```

#### Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--dry-run` | No | - | Show what would be removed without modifying the file |

#### Behavior

1. Reads `$HOME/.claude.json` (exits gracefully if missing)
2. Verifies `jq` is available (required dependency)
3. Scans `.projects` keys for non-existent directories
4. Scans `.githubRepoPaths` arrays for non-existent directories
5. If `--dry-run`, prints what would be removed and exits
6. Otherwise, removes stale entries and writes changes atomically

#### Example

```bash
# Preview what would be removed
lol claude-clean --dry-run

# Remove stale entries
lol claude-clean
```

### lol usage

Report Claude Code token usage statistics.

```bash
lol usage [--today | --week]
```

Parses JSONL files from `~/.claude/projects/**/*.jsonl` to extract and aggregate token usage statistics by time bucket.

#### Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--today` | No | Yes | Show usage by hour for the last 24 hours |
| `--week` | No | - | Show usage by day for the last 7 days |

#### Example

```bash
# Show today's usage by hour (default)
lol usage

# Show weekly usage by day
lol usage --week
```

### lol serve

Long-running server that polls GitHub Projects for "Plan Accepted" issues and automatically invokes `wt spawn` to start implementation.

```bash
lol serve --tg-token=<token> --tg-chat-id=<chat_id> [--period=5m] [--num-workers=5]
```

#### Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--tg-token` | Yes | - | Telegram bot token for remote approval |
| `--tg-chat-id` | Yes | - | Telegram chat ID for approval messages |
| `--period` | No | 5m | Polling interval (format: Nm or Ns) |
| `--num-workers` | No | 5 | Maximum concurrent headless workers (0 = unlimited) |

#### Requirements

- Must be run from a bare repository with `wt init` completed
- GitHub CLI (`gh`) must be authenticated
- Project must be associated via `lol project --associate`

#### Behavior

**Implementation Discovery:**
1. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
2. For each candidate, checks project status via per-issue GraphQL lookup
3. Filters issues by:
   - Project Status field = "Plan Accepted" (approval gate)
   - Label = `agentize:plan` (discovery filter)
4. For each matching issue without an existing worktree:
   - Invokes `wt spawn <issue-number>` with TG credentials

**Refinement Discovery:**
1. Discovers refinement candidates with both `agentize:plan` and `agentize:refine` labels
2. Filters issues by:
   - Project Status field = "Proposed"
   - Labels include both `agentize:plan` and `agentize:refine`
3. For each matching issue:
   - Sets status to "Refining" (best-effort claim)
   - Runs `/ultra-planner --refine` headlessly
   - On completion: resets status to "Proposed" and removes `agentize:refine` label

**Polling Loop:**
- Continues polling until interrupted (Ctrl+C)

#### Environment Variables

The following environment variables are passed to spawned Claude sessions:
- `AGENTIZE_USE_TG=1`
- `TG_API_TOKEN=<tg-token>`
- `TG_CHAT_ID=<tg-chat-id>`
