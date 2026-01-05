# CLI Reference Documentation

This directory contains detailed reference documentation for Agentize command-line tools.

## Purpose

These documents provide comprehensive command-line interface specifications, including all flags, options, usage patterns, and examples for each tool in the Agentize framework.

## Files

### lol.md
The `lol` command interface for creating AI-powered SDKs and managing GitHub Projects v2. Documents `lol init` (SDK initialization), `lol update` (SDK updates), `lol project` (GitHub Projects integration), all command flags (--name, --lang, --path, --source, --metadata-only, --create, --associate, --automation), template system integration, and zsh completion support.

### wt.md
The `wt` command interface for git worktree management. Documents `wt init` (worktree initialization), `wt spawn` (issue-based worktree creation), `wt main` (switch to main worktree), `.agentize.yaml` metadata integration, and zsh completion support.

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
