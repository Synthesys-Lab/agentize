# Agentize Server Module

Polling server for GitHub Projects v2 automation.

## Purpose

This module implements a long-running server that:
1. Sends a Telegram startup notification (if configured)
2. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
3. Checks per-issue project status via GraphQL to enforce:
   - "Plan Accepted" approval gate (for implementation via `wt spawn`)
   - "Proposed" + `agentize:refine` label (for refinement via `/ultra-planner --refine`)
4. Spawns worktrees for ready issues via `wt spawn` or triggers refinement headlessly

## Module Layout

| File | Purpose |
|------|---------|
| `__main__.py` | CLI entry point, polling coordinator, and re-export hub |
| `github.py` | GitHub issue/PR discovery via `gh` CLI and GraphQL queries |
| `workers.py` | Worktree spawn/rebase via `wt` CLI and worker status file management |
| `notify.py` | Telegram message formatting (startup, assignment, completion) |
| `session.py` | Session state file lookups for completion detection |
| `log.py` | Shared `_log` helper with source location formatting |

## Import Policy

All public functions are re-exported from `__main__.py`:

```python
# Tests and external code should use this pattern:
from agentize.server.__main__ import read_worker_status

# Internal modules import from specific files:
from agentize.server.log import _log
from agentize.server.workers import spawn_worktree
```

This re-export policy preserves backward compatibility with existing tests that import from `__main__`.

## Module Dependencies

```
__main__.py
    ├── github.py
    │       └── log.py
    ├── workers.py
    │       └── log.py
    ├── notify.py
    │       └── log.py
    └── session.py
```

Leaf module `log.py` has no internal dependencies to avoid import cycles.

## Usage

```bash
# Via lol CLI (recommended)
lol serve --tg-token=<token> --tg-chat-id=<id> --period=5m

# Direct Python invocation
python -m agentize.server --period=5m --tg-token=<token> --tg-chat-id=<id>
```

Telegram credentials can also be provided via environment variables:
- `TG_API_TOKEN` - Telegram Bot API token
- `TG_CHAT_ID` - Telegram chat ID

CLI arguments take precedence over environment variables.

## Configuration

Reads project association from `.agentize.yaml`:
```yaml
project:
  org: <organization>
  id: <project-number>
```

## Debug Logging

Set `HANDSOFF_DEBUG=1` to enable detailed logging of issue filtering decisions. See [docs/feat/server.md](../../../docs/feat/server.md#issue-filtering-debug-logs) for output format and examples.
