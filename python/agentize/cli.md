# Python CLI Interface

Optional argparse-based entrypoint for the `lol` CLI.

## Usage

```bash
python -m agentize.cli <command> [options]
```

## Commands

The Python CLI supports the same commands as the shell implementation:

| Command | Description |
|---------|-------------|
| `upgrade` | Upgrade agentize installation |
| `project` | GitHub Projects v2 integration |
| `serve` | GitHub Projects polling server |
| `usage` | Report Claude Code token usage statistics (--cache, --cost) |
| `claude-clean` | Remove stale project entries from `~/.claude.json` |
| `version` | Display version information |
| `impl` | Issue-to-implementation loop (Python workflow, optional `--wait-for-ci`) |
| `simp` | Simplify code without changing semantics (optional `--focus`, `--issue`) |

## Top-level Flags

| Flag | Description |
|------|-------------|
| `--complete <topic>` | Shell-agnostic completion helper |
| `--version` | Display version information |

## Implementation

The Python CLI delegates to private shell helpers for most commands via `bash -c` with `AGENTIZE_HOME` set. The `impl` command calls the Python workflow module directly:

```python
subprocess.run(
    ["bash", "-c", f"source $AGENTIZE_HOME/setup.sh && _lol_cmd_{command} {args}"],
    env={**os.environ, "AGENTIZE_HOME": agentize_home}
)
```

This preserves the shell implementation for most commands while enabling:
- Argparse-style flag parsing
- Python scripting integration
- Non-sourced environment usage

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTIZE_HOME` | Yes | Path to agentize installation (auto-detected from repo root if unset) |

## Examples

```bash
# Upgrade installation
python -m agentize.cli upgrade

# Get completion hints
python -m agentize.cli --complete commands

# Display version
python -m agentize.cli --version

# Clean stale project entries
python -m agentize.cli claude-clean --dry-run
python -m agentize.cli claude-clean

# Usage with cache and cost
python -m agentize.cli usage --cache
python -m agentize.cli usage --cost
python -m agentize.cli usage --week --cache --cost

# Simplify and publish to an issue when the report starts with Yes.
python -m agentize.cli simp --issue 123
python -m agentize.cli simp README.md --issue 123

# Simplify with a focus description
python -m agentize.cli simp --focus "Refactor for clarity"
python -m agentize.cli simp README.md --focus "Reduce nesting"

# Run impl workflow and wait for PR CI
python -m agentize.cli impl 42 --wait-for-ci
```

## Related Documentation

- `../README.md` - Package overview
- `../../src/cli/lol.md` - Shell interface documentation
- `../../docs/cli/lol.md` - User documentation
