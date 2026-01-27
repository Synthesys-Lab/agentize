# `install`: Agentize Installer Script

## Overview

One-command installer for Agentize that clones the repository, initializes the worktree layout, runs setup, and provides shell RC integration instructions.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

Or with custom options:

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash -s -- [OPTIONS]
```

Direct execution from local clone:

```bash
./scripts/install [OPTIONS]
```

## Options

- `--dir <path>` - Installation directory (default: `$HOME/.agentize`)
- `--repo <url-or-path>` - Git repository URL or local path (default: https://github.com/SyntheSys-Lab/agentize.git)
- `--help` - Display help message and exit

## Behavior

The installer performs the following steps:

1. **Dependency check** - Verifies `git`, `make`, and `bash` are available
2. **Clone repository** - Clones (or copies from local path) to install directory
3. **Initialize worktree** - Runs `wt init` to create `trees/main` worktree
4. **Run setup** - Executes `make setup` in `trees/main` to generate `setup.sh`
5. **Register Claude plugin** (optional) - If `claude` CLI is available:
   - Removes any stale marketplace/plugin entries
   - Registers the install directory as a local plugin marketplace
   - Installs `agentize@agentize` plugin
   - All Claude steps are non-fatal; failures are logged but do not block installation
6. **Print instructions** - Shows shell RC integration commands

## Post-Install

After installation completes, add the following to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source $HOME/.agentize/trees/main/setup.sh
```

Then restart your shell or source the RC file:

```bash
source ~/.bashrc  # or ~/.zshrc
```

This enables the `wt` and `lol` commands from any directory.

## Exit Codes

- `0` - Installation successful
- `1` - Installation failed (missing dependencies, clone failed, init failed, setup failed, or install directory already exists)

## Examples

**Default installation:**

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash
```

**Custom install directory:**

```bash
curl -fsSL https://raw.githubusercontent.com/SyntheSys-Lab/agentize/main/scripts/install | bash -s -- --dir ~/my-agentize
```

**Install from local repository (for testing):**

```bash
./scripts/install --repo /path/to/local/agentize --dir /tmp/test-install
```

## Safety Features

- **No automatic RC modification** - The installer never modifies shell RC files; it only prints instructions for manual integration
- **Install directory check** - Fails if target directory already exists to prevent accidental overwrites
- **Dependency validation** - Checks for required commands before proceeding

## Troubleshooting

**Error: Install directory already exists**

The installer refuses to overwrite existing installations. Either remove the directory or specify a different `--dir`.

```bash
rm -rf $HOME/.agentize  # Remove existing installation
```

**Error: Missing dependencies**

Install the required dependencies (`git`, `make`, `bash`) using your system package manager.

**Error: Failed to initialize worktree**

Ensure the cloned repository is a valid git repository and `wt init` can run successfully. Check that the repository has a `main` or `master` branch.

## Implementation Notes

- Reuses existing `wt init` behavior for worktree initialization
- Reuses `make setup` for environment setup
- Does not implement rollback, uninstall, or update flows
- Plugin registration is optional and non-fatal; `claude` CLI absence is handled gracefully

## Plugin Registration Troubleshooting

**Plugin not appearing after install**

The local marketplace registration may not persist across Claude restarts. Re-register manually:

```bash
claude plugin marketplace add "$HOME/.agentize"
claude plugin install agentize@agentize
```

**Stale plugin entries**

If a previous installation left stale entries, the installer cleans them automatically. To do this manually:

```bash
claude plugin uninstall agentize@agentize
claude plugin marketplace remove agentize
claude plugin marketplace add "$HOME/.agentize"
claude plugin install agentize@agentize
```
