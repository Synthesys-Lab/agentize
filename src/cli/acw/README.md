# acw Module Directory

## Purpose

Modular implementation of the Agent CLI Wrapper (`acw`) command.

## Module Map

| File | Dependencies | Exports |
|------|--------------|---------|
| `helpers.sh` | None | `acw_validate_args`, `acw_check_cli`, `acw_ensure_output_dir`, `acw_check_input_file` |
| `providers.sh` | `helpers.sh` | `acw_invoke_claude`, `acw_invoke_codex`, `acw_invoke_opencode`, `acw_invoke_cursor` |
| `dispatch.sh` | `helpers.sh`, `providers.sh` | `acw` |

## Load Order

The parent `acw.sh` sources modules in this order:

1. `helpers.sh` - No dependencies
2. `providers.sh` - Uses helper functions
3. `dispatch.sh` - Uses helpers and providers

## Architecture

```
acw.sh (thin loader)
    |
    +-- helpers.sh
    |     +-- acw_validate_args()
    |     +-- acw_check_cli()
    |     +-- acw_ensure_output_dir()
    |     +-- acw_check_input_file()
    |
    +-- providers.sh
    |     +-- acw_invoke_claude()
    |     +-- acw_invoke_codex()
    |     +-- acw_invoke_opencode()
    |     +-- acw_invoke_cursor()
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
