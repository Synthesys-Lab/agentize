# _lol

Zsh completion definition for the `lol` CLI.

## Purpose
Provide interactive completion for `lol` subcommands and flags, while keeping the
completion lists in sync with the CLI via `lol --complete` and maintaining a
static fallback for offline or missing-binary cases.

## External Interface

### _lol()
Zsh completion entrypoint registered by `#compdef lol`.

**Behavior:**
- Resolves available subcommands from `lol --complete commands` when available.
- Falls back to a static command list with descriptions if dynamic fetch fails.
- Routes argument completion to a subcommand-specific handler based on the first
  positional token.

### Subcommand handlers
Each handler provides completion for a specific `lol` subcommand:
- `_lol_plan()` completes flags and the free-form feature description.
- `_lol_impl()` completes flags and the required issue number.
- `_lol_project()` completes project modes and flags.
- `_lol_usage()` completes usage-reporting flags.
- `_lol_claude_clean()` completes cleanup flags.
- `_lol_upgrade()` completes upgrade flags.
- `_lol_use_branch()` completes the remote/branch argument.
- `_lol_version()` and `_lol_serve()` are no-flag handlers.

## Internal Helpers

### Dynamic completion lists
Handlers attempt to load flag lists using `lol --complete <topic>` and store them
in local arrays. When the dynamic list is empty, they fall back to static flags to
ensure completion remains usable in minimal environments.

### Flag descriptions
When dynamic lists only provide flag names, handlers attach descriptions locally
for the known flags so the completion UI remains informative.

## Design Rationale
- Using `lol --complete` keeps completion aligned with the CLI command registry.
- Static fallbacks preserve completion when the binary is unavailable or the
  helper fails.
- Descriptions are sourced from the CLI documentation to minimize drift and keep
  the UX consistent with the published interface.
- `_lol_plan()` uses `_arguments -s` to enable smart option matching so unique
  flag prefixes (like `--ed`) complete immediately without requiring a second tab.
