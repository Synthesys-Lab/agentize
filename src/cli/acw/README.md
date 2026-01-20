# acw Module Directory

## Purpose

Modular implementation of the Agent CLI Wrapper (`acw`) command.

## Module Map

| File | Dependencies | Exports |
|------|--------------|---------|
| `helpers.sh` | None | `_acw_validate_args`, `_acw_check_cli`, `_acw_ensure_output_dir`, `_acw_check_input_file` (private) |
| `providers.sh` | `helpers.sh` | `acw_invoke_claude`, `acw_invoke_codex`, `acw_invoke_opencode`, `acw_invoke_cursor` |
| `completion.sh` | None | `acw_complete` |
| `dispatch.sh` | `helpers.sh`, `providers.sh`, `completion.sh` | `acw` |

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
    +-- providers.sh
    |     +-- acw_invoke_claude()
    |     +-- acw_invoke_codex()
    |     +-- acw_invoke_opencode()
    |     +-- acw_invoke_cursor()
    |
    +-- completion.sh
    |     +-- acw_complete()
    |
    +-- dispatch.sh
          +-- acw()  [main entry point]
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

- Function names prefixed with `acw_` for public API
- Function names prefixed with `_acw_` for internal use
- Exit codes follow `acw.md` specification (0-4, 127)
- All functions support both bash and zsh
