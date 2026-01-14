# SDK Template Tests

## Purpose

This directory previously contained unit tests for SDK template generation. The SDK template tests have been removed along with the `lol apply` command.

## Historical Context

The SDK template tests validated:
- C, C++, and Python project template generation
- Correct project structure and build configuration
- File generation and substitution correctness

## Current Status

The `lol apply --init` and `lol apply --update` commands have been removed. SDK projects are now set up by copying the `.claude/` directory directly from the Agentize installation.

See [docs/architecture/sdk.md](../../docs/architecture/sdk.md) for the current SDK setup workflow.

## Related Documentation

- [templates/](../../templates/) - SDK template source files (for reference)
- [docs/architecture/sdk.md](../../docs/architecture/sdk.md) - SDK structure documentation
- [tests/README.md](../README.md) - Test suite overview
