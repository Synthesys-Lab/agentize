# CLI Reference Documentation

This directory contains detailed reference documentation for Agentize command-line tools.

## Purpose

These documents provide comprehensive command-line interface specifications, including all flags, options, usage patterns, and examples for each tool in the Agentize framework.

**Canonical source location:** CLI implementations live in `src/cli/` as source-first libraries. The documentation here describes the user-facing interface; see `src/cli/*.md` for function-level interface documentation and `src/cli/*/README.md` for module maps.

## Files

### install.md
The `install` script for one-command Agentize installation. Documents installation flow (clone, worktree init, setup), command-line options (--dir, --repo, --help), post-install shell RC integration, and troubleshooting.

### Note on lol.md
The `lol.md` documentation has been removed. See [docs/cli/lol.md](../../cli/lol.md) for the current `lol` command documentation. The `lol` command now provides: `lol upgrade` (installation upgrade), `lol project` (GitHub Projects integration), `lol usage` (token usage reporting), `lol claude-clean` (stale entry cleanup), and `lol version` (version information).

### wt.md
The `wt` command interface for git worktree management. Documents `wt init` (worktree initialization), `wt spawn` (issue-based worktree creation), `wt goto` (navigate to worktrees), `.agentize.yaml` metadata integration, and zsh completion support.

## Usage

Quick reference:
- `lol --help` - Display lol command help
- `wt --help` - Display wt command help

For detailed documentation including examples and advanced usage, refer to the individual `.md` files.

## Integration

CLI documentation is referenced from:
- Main [README.md](../README.md) under "CLI Reference"
- Tutorial series in [docs/tutorial/](../tutorial/)
- Skills and commands that invoke these CLI tools

## Troubleshooting

### Zsh Tab Completion Not Working

**Problem:** After running `make setup` and `source setup.sh`, tab completion doesn't work for `wt`, `lol`, or other commands.

**Cause:** Stale zsh completion cache from before completion files (`_wt`, `_lol`) were moved to `src/completion/`.

**Solution:**
```bash
# Delete the completion cache
rm -f ~/.zcompdump ~/.zcompdump.zwc

# Restart your zsh session
exec zsh

# Or just re-source setup.sh
source setup.sh
```

After this one-time cleanup, tab completions should work normally.

**Verify it's working:**
```bash
# Check if command is available
which wt

# Try tab completion
wt <TAB>
```
