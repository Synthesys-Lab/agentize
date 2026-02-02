# parsers.sh

Argument parsing layer for `lol` subcommands. Each parser validates flags and
translates them into positional arguments for the command implementations.

## External Interface

None. Parsers are private and invoked by `lol()`.

## Internal Helpers

### _lol_parse_upgrade()
Accepts optional `--keep-branch` and passes the flag to `_lol_cmd_upgrade`.

### _lol_parse_use_branch()
Parses `<remote>/<branch>` or `<branch>` (defaulting the remote to `origin`) and
calls `_lol_cmd_use_branch`.

### _lol_parse_project()
Parses `--create`, `--associate`, and `--automation` modes plus optional flags,
then calls `_lol_cmd_project` with the corresponding positional arguments.

### _lol_parse_serve()
Rejects CLI flags and delegates to `_lol_cmd_serve` (configuration is YAML-only).

### _lol_parse_claude_clean()
Handles `--dry-run` and calls `_lol_cmd_claude_clean`.

### _lol_parse_usage()
Parses `--today`, `--week`, `--cache`, `--cost` before calling `_lol_cmd_usage`.

### _lol_parse_plan()
Supports `--dry-run`, `--verbose`, `--editor`, and `--refine` flags, then calls
`_lol_cmd_plan` with normalized arguments.

In refine mode, editor-provided `feature_desc` is preserved; if both editor text
and `refine_instructions` are present, they are concatenated with a blank line
(editor text first, positional instructions second).

### _lol_parse_impl()
Validates positional arguments and flags for `lol impl`, then calls `_lol_cmd_impl`.
