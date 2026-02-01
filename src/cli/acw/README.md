# acw Module Directory

## Purpose

Modular implementation of the Agent CLI Wrapper (`acw`) command.

## Module Map

| File | Dependencies | Exports |
|------|--------------|---------|
| `helpers.sh` | None | `_acw_validate_args`, `_acw_check_cli`, `_acw_ensure_output_dir`, `_acw_check_input_file` (private) |
| `providers.sh` | `helpers.sh` | `_acw_invoke_claude`, `_acw_invoke_codex`, `_acw_invoke_opencode`, `_acw_invoke_cursor` (private) |
| `completion.sh` | None | `_acw_complete` (private) |
| `dispatch.sh` | `helpers.sh`, `providers.sh`, `completion.sh` | `acw` (public) |

## Load Order

The parent `acw.sh` sources modules in this order:

1. `helpers.sh` - No dependencies (private helper functions)
2. `providers.sh` - Uses helper functions
3. `completion.sh` - No dependencies (completion support)
4. `dispatch.sh` - Uses helpers, providers, and completion

## Architecture

```
acw.sh (thin loader)
    |
    +-- helpers.sh (private)
    |     +-- _acw_validate_args()
    |     +-- _acw_check_cli()
    |     +-- _acw_ensure_output_dir()
    |     +-- _acw_check_input_file()
    |
    +-- providers.sh (private)
    |     +-- _acw_invoke_claude()
    |     +-- _acw_invoke_codex()
    |     +-- _acw_invoke_opencode()
    |     +-- _acw_invoke_cursor()
    |
    +-- completion.sh (private)
    |     +-- _acw_complete()
    |
    +-- dispatch.sh
          +-- acw()  [public entry point]
          +-- _acw_usage()
```

## Provider Support Matrix

| Provider | Binary | Input Method | Output Method | Status |
|----------|--------|--------------|---------------|--------|
| claude | `claude` | `-p @file` | `> file` | Full |
| codex | `codex` | `< file` | `> file` | Full |
| opencode | `opencode` | TBD | TBD | Best-effort |
| cursor | `agent` | TBD | TBD | Best-effort |

## Conventions

- Only `acw` is the public function (no prefix)
- All other function names prefixed with `_acw_` for internal use
- Exit codes follow `acw.md` specification (0-4, 127)
- All functions support both bash and zsh
- `--stdout` mode routes output to `/dev/stdout` and merges provider stderr into stdout for the invocation
