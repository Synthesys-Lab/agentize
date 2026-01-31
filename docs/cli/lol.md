# lol CLI

The `lol` command provides SDK management utilities: upgrade, project management, usage reporting, planning, and automation server capabilities.

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

The Python entrypoint sources `setup.sh` and delegates to the shell implementation. `lol` is the only public shell entrypoint; helper functions are private implementation details. Use the Python entrypoint for non-sourced environments or scripting contexts where argparse-style parsing is preferred.

## Commands

### lol upgrade

Upgrade the agentize installation.

```bash
lol upgrade
```

The upgrade process has three phases:
1. **Pull updates**: Runs `git pull --rebase` to fetch latest changes
2. **Rebuild environment**: Runs `make setup` to regenerate `setup.sh` with any build process changes
3. **Update Claude plugin** (optional): If `claude` CLI is available, updates the local marketplace and plugin registration. This step is non-fatal; failures do not block the upgrade.

This mirrors the installation process in `scripts/install`, ensuring updates to the build configuration and plugin are applied.

### lol project

Manage GitHub Projects v2 integration.

```bash
lol project --create [--org <owner>] [--title <title>]
lol project --associate <owner>/<id>
lol project --automation [--write <path>]
```

The `--org` flag accepts either an organization or personal user login. When omitted, it defaults to the repository owner (which may be an organization or personal account).

This command shares implementation with `/setup-viewboard` via the shared project library (`src/cli/lol/project-lib.sh`).

See [Project Management](../architecture/project.md) for details.

**See also:** `/setup-viewboard` for self-contained project setup with labels, automation, and Status field verification.

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
| `--cache` | No | - | Include cache token statistics (cache_read, cache_write columns) |
| `--cost` | No | - | Show cost estimate based on model pricing |

#### Example

```bash
# Show today's usage by hour (default)
lol usage

# Show weekly usage by day
lol usage --week
```

### lol plan

Run the multi-agent debate pipeline.

```bash
lol plan [--dry-run] [--verbose] [--editor] [--refine <issue-no> [refinement-instructions]] \
  [<feature-description>]
lol plan --refine <issue-no> [refinement-instructions]
```

Runs the full multi-agent debate pipeline for a feature description, producing a consensus implementation plan. This is the preferred entrypoint for the planner pipeline.

#### Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--dry-run` | No | - | Skip GitHub issue creation; use timestamp-based artifacts |
| `--verbose` | No | - | Print detailed stage logs (quiet by default) |
| `--editor` | No | - | Open $EDITOR to compose feature description |
| `--refine <issue-no> [refinement-instructions]` | No | - | Refine an existing plan issue (optional focus) |

By default, `lol plan` creates a GitHub issue when `gh` is available. Use `--dry-run` to skip issue creation and use timestamp-based artifact naming instead.

When `--refine` is set, the issue body is fetched from GitHub and used as the debate context. Optional refinement instructions are appended to the context to guide the agents. Refinement runs write artifacts prefixed with `issue-refine-<N>` and update the existing issue unless `--dry-run` is provided. This mode requires authenticated `gh` access to read the issue body.

#### Backend configuration (.agentize.local.yaml)

Configure planner backends via `.agentize.local.yaml` instead of CLI flags:

```yaml
planner:
  backend: claude:opus
  understander: claude:sonnet
  bold: claude:opus
  critique: claude:opus
  reducer: claude:opus
```

Stage-specific keys override `planner.backend`. If a key is missing, defaults remain `claude:sonnet` for understander and `claude:opus` for bold/critique/reducer.

#### Example

```bash
# Run pipeline with default issue creation
lol plan "Add user authentication with JWT tokens"

# Run pipeline without creating a GitHub issue
lol plan --dry-run "Refactor database layer for connection pooling"

# Run pipeline with detailed stage output
lol plan --verbose "Add real-time notifications"

# Refine an existing plan issue
lol plan --refine 42 "Focus on reducing complexity"

# Refine without publishing back to GitHub (still writes issue-refine artifacts)
lol plan --dry-run --refine 42 "Add more error handling and edge cases"

# Compose the feature description in your editor
lol plan --editor --dry-run
```

See [planner pipeline module](planner.md) for pipeline stage details and artifact naming.

### lol impl

Automate the issue-to-implementation loop using `wt` + `acw`.

```bash
lol impl <issue-no> [--backend <provider:model>] [--max-iterations <N>] [--yolo]
```

#### Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--backend` | No | `codex:gpt-5.2-codex` | Backend in `provider:model` form |
| `--max-iterations` | No | `10` | Maximum `acw` iterations before giving up |
| `--yolo` | No | Off | Pass through to provider CLI options (Claude via acw maps to `--dangerously-skip-permissions`) |

#### Issue prefetch

Before the loop starts, `lol impl` attempts to fetch the issue title/body (and labels if present) via `gh issue view` and writes it to `.tmp/issue-<N>.md`. If the file is non-empty, the initial prompt references it; otherwise it falls back to `Implement issue #<N>`.

#### Completion marker

Create `.tmp/finalize.txt` in the worktree and include `Issue <N> resolved` to finish.
The first line of the completion file is used as the PR title.

#### Git workflow

Each iteration stages and commits changes (skipping commits when there are no changes). A `.tmp/commit-report-iter-<N>.txt` file is required for each iteration and is used as the commit message for iteration `<N>`. On completion, the branch is pushed to `upstream` (or `origin`) and the PR targets `master` (or `main`).

#### Example

```bash
# Start implementation loop for issue 42
lol impl 42

# Use a different backend
lol impl 42 --backend cursor:gpt-5.2-codex

# Limit iterations and enable yolo mode
lol impl 42 --max-iterations 5 --yolo
```

### lol serve

Long-running server that polls GitHub Projects for "Plan Accepted" issues and automatically invokes `wt spawn` to start implementation.

```bash
lol serve
```

Configure `server.period` and `server.num_workers` in `.agentize.local.yaml`:

```yaml
server:
  period: 5m       # Polling interval (format: Nm or Ns)
  num_workers: 5   # Maximum concurrent headless workers (0 = unlimited)
```

Telegram credentials are also loaded from `.agentize.local.yaml`. The server searches for this file in: project root → `$AGENTIZE_HOME` → `$HOME`. If no credentials are configured, the server runs in notification-less mode.

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
   - Invokes `wt spawn <issue-number>`

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

#### Configuration

Telegram and handsoff settings are loaded from `.agentize.local.yaml`:

```yaml
telegram:
  enabled: true
  token: "your-bot-token"
  chat_id: "your-chat-id"
```

See [Configuration Reference](../envvar.md) for the complete schema.
