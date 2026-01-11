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
| `apply` | Unified init/update entrypoint |
| `init` | Initialize new SDK project |
| `update` | Update existing project |
| `upgrade` | Upgrade agentize installation |
| `project` | GitHub Projects v2 integration |
| `serve` | GitHub Projects polling server |
| `usage` | Report Claude Code token usage statistics (--cache, --cost) |
| `claude-clean` | Remove stale project entries from `~/.claude.json` |
| `version` | Display version information |

## Top-level Flags

| Flag | Description |
|------|-------------|
| `--complete <topic>` | Shell-agnostic completion helper |
| `--version` | Display version information |

## Implementation

The Python CLI delegates to shell functions via `bash -c` with `AGENTIZE_HOME` set:

```python
subprocess.run(
    ["bash", "-c", f"source $AGENTIZE_HOME/setup.sh && lol_cmd_{command} {args}"],
    env={**os.environ, "AGENTIZE_HOME": agentize_home}
)
```

This preserves the shell implementation as canonical while enabling:
- Argparse-style flag parsing
- Python scripting integration
- Non-sourced environment usage

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTIZE_HOME` | Yes | Path to agentize installation (auto-detected from repo root if unset) |

## Examples

```bash
# Initialize project
python -m agentize.cli init --name my-project --lang python

# Update project
python -m agentize.cli update --path /path/to/project

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
```

## Related Documentation

- `../README.md` - Package overview
- `../../src/cli/lol.md` - Shell interface documentation
- `../../docs/cli/lol.md` - User documentation
