# commands.sh

Loader for per-command `lol` implementations stored under `commands/`.

## External Interface

None. This module is sourced by `lol.sh` to register `_lol_cmd_*` functions.

## Internal Helpers

### _lol_commands_dir()
Resolves the directory containing the `lol` CLI modules for both bash and zsh,
so command files are sourced from the correct location regardless of the shell
invocation context.

### _LOL_COMMANDS_DIR
Module-level path set by `_lol_commands_dir()`. Used to source individual
command implementations in a stable order.
