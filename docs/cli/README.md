# CLI Reference Documentation

This directory contains detailed reference documentation for Agentize command-line tools.

## Purpose

These documents provide comprehensive command-line interface specifications, including all flags, options, usage patterns, and examples for each tool in the Agentize framework.

**Canonical source location:** CLI implementations live in `src/cli/` as source-first libraries. The documentation here describes the user-facing interface; see `src/cli/*.md` for function-level interface documentation.

## Files

### install.md
The `install` script for one-command Agentize installation. Documents installation flow (clone, worktree init, setup), command-line options (--dir, --repo, --help), post-install shell RC integration, and troubleshooting.

### lol.md
The `lol` command interface for creating AI-powered SDKs and managing GitHub Projects v2. Documents `lol apply` (unified init/update entrypoint), `lol init` (SDK initialization), `lol update` (SDK updates), `lol upgrade` (agentize installation upgrade), `lol version` (version information), `lol project` (GitHub Projects integration), all command flags (--name, --lang, --path, --source, --metadata-only, --create, --associate, --automation, --init, --update), template system integration, and zsh completion support.

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
