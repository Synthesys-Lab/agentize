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

1. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
2. For each candidate, checks project status via per-issue GraphQL lookup
3. Filters issues by:
   - Project Status field = "Plan Accepted" (approval gate)
   - Label = `agentize:plan` (discovery filter)
4. For each matching issue without an existing worktree:
   - Invokes `wt spawn <issue-number>` with TG credentials
5. Continues polling until interrupted (Ctrl+C)

#### Environment Variables

The following environment variables are passed to spawned Claude sessions:
- `AGENTIZE_USE_TG=1`
- `TG_API_TOKEN=<tg-token>`
- `TG_CHAT_ID=<tg-chat-id>`
