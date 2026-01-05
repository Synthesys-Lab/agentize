# Shell Completion Scripts

This directory contains shell completion scripts for Agentize CLI commands.

## Purpose

Provides interactive tab-completion support for CLI commands, improving user experience by:
- Suggesting available subcommands and flags
- Offering context-aware value completion (e.g., language values, file paths)
- Reducing typing and preventing errors through autocomplete

## File Organization

Completion scripts follow the naming pattern `_<command>` for zsh completions:

- `_wt` - Completion for the `wt` (worktree) command
- `_lol` - Completion for the `lol` (SDK CLI) command

## How Completions Are Loaded

Completions are automatically enabled when users run `make setup` and source the generated `setup.sh`:

1. `make setup` generates `setup.sh` which adds `scripts/completions/` to zsh's `fpath`
2. When user sources `setup.sh`, zsh's completion system (`compinit`) discovers completion files
3. Tab-completion becomes available for all commands with `_<command>` files in this directory

## Adding New Completion Scripts

To add completion support for a new command:

1. **Add completion helper to the command script** (e.g., `scripts/new-command-cli.sh`):
   ```bash
   new_command_complete() {
       local topic="$1"
       case "$topic" in
           commands)
               echo "subcommand1"
               echo "subcommand2"
               ;;
           # ... additional topics
       esac
   }

   new_command() {
       if [ "$1" = "--complete" ]; then
           new_command_complete "$2"
           return 0
       fi
       # ... rest of command implementation
   }
   ```

2. **Create zsh completion script** `scripts/completions/_new_command`:
   ```zsh
   #compdef new_command

   _new_command() {
       # Use new_command --complete for dynamic completion
       # with fallback to static lists
       # ... implementation following _wt or _lol pattern
   }

   _new_command "$@"
   ```

3. **Add tests** in `tests/cli/` and `tests/lint/`:
   - `test-new-command-complete-commands.sh` - Test command completion
   - `test-new-command-complete-flags.sh` - Test flag completion
   - `tests/lint/test-new-command-zsh-completion-file.sh` - Verify file exists

4. **Document in command documentation** (e.g., `docs/cli/new-command.md`):
   - Add "Shell Completion (zsh)" section with setup instructions
   - Add "Completion Helper Interface" section documenting topics

## Design Pattern

All completion scripts follow a consistent pattern:

**Shell-agnostic helper** (`<command> --complete <topic>`):
- Returns newline-delimited tokens
- No shell-specific syntax
- Testable independently
- Works before full environment setup

**Zsh completion script** (`_<command>`):
- Attempts dynamic fetch via `<command> --complete`
- Falls back to static lists if command unavailable
- Adds descriptions for better UX
- Handles subcommand-specific completions

This two-tier approach ensures:
- Completions work even when command isn't in PATH
- Easy testing of completion logic
- Future extensibility to other shells (bash, fish)
- Single source of truth for command structure
