# test-lol-command-functions-loaded.sh

Ensures private `_lol_cmd_*` functions are registered after sourcing `lol.sh` and
public `lol_cmd_*` helpers remain unavailable.

## Coverage

- `_lol_cmd_use_branch` and other command handlers are defined.
- Public `lol_cmd_*` aliases are not exported.
