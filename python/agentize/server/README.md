# Agentize Server Module

Polling server for GitHub Projects v2 automation.

## Purpose

This module implements a long-running server that:
1. Sends a Telegram startup notification (if configured)
2. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
3. Checks per-issue project status via GraphQL to enforce:
   - "Plan Accepted" approval gate (for implementation via `wt spawn`)
   - "Proposed" + `agentize:refine` label (for refinement via `/ultra-planner --refine`)
4. Discovers feature request issues using `gh issue list --label agentize:dev-req --state open`
5. Spawns worktrees for ready issues via `wt spawn`, triggers refinement, or runs feature request planning via `/ultra-planner --from-issue`
6. Discovers conflicting PRs with `agentize:pr` label via `gh pr list` and rebases their worktrees automatically
7. Discovers PRs with unresolved review threads (Status=`Proposed`) and spawns `/resolve-review` to address them

## Module Layout

| File | Purpose |
|------|---------|
| `__main__.py` | CLI entry point, polling coordinator, and re-export hub |
| `runtime_config.py` | Runtime config parser for `.agentize.local.yaml` |
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
lol serve --period=5m --num-workers=5

# Direct Python invocation
python -m agentize.server --period=5m --num-workers=5
```

Telegram credentials are loaded from `.agentize.local.yaml`. The server searches for this file in: project root → `$AGENTIZE_HOME` → `$HOME`.

## Configuration

Reads project association from `.agentize.yaml`:
```yaml
project:
  org: <organization>
  id: <project-number>
```

### Runtime Configuration

For server-specific settings, use `.agentize.local.yaml` (git-ignored):

```yaml
server:
  period: 5m
  num_workers: 5

telegram:
  token: "your-bot-token"
  chat_id: "your-chat-id"

workflows:
  impl:
    model: opus
  refine:
    model: sonnet
  dev_req:
    model: sonnet
  rebase:
    model: haiku
```

**Precedence:** `.agentize.local.yaml` > defaults

**YAML search order:**
1. Project root `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

See [Server Runtime Configuration](../../../docs/feat/server.md#runtime-configuration) for details.

## Debug Logging

Set `handsoff.debug: true` in `.agentize.local.yaml` to enable detailed logging of issue filtering decisions. Debug messages use prefixes like `[pr-rebase]` for PR conflict handling. See [docs/feat/server.md](../../../docs/feat/server.md#issue-filtering-debug-logs) for output format and examples.
