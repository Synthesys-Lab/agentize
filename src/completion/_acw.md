# _acw

## Purpose

Zsh completion definition for the `acw` command. Provides flag hints, provider
selection, and positional argument guidance.

## External Interface

### Completion function
The file defines the `_acw` completion function and registers it for `acw` via
`#compdef acw`.

**Behavior**:
- Uses `acw --complete providers` when available to populate provider names.
- Falls back to a static provider list with descriptions if dynamic completion
  is unavailable.
- Offers flags from `acw --complete cli-options` (see `docs/cli/acw.md`) plus
  completion-only flags like `--complete` and `-h`.
- Treats `--chat` as an optional session-id and lists common provider options
  (`--model`, `--max-tokens`, `--yolo`) as hintable flags.
- Marks input/output positions as optional to reflect editor/stdout modes.

## Internal Helpers

None.
