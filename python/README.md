# Python Packages

This directory contains Python packages for the Agentize SDK.

## Packages

- `agentize/` - Core SDK package (see `agentize/README.md`)

## Usage

The packages are automatically available when using `sys.path.insert()` from hook scripts,
or by setting `PYTHONPATH` via `make setup`.

```bash
# Option 1: Source setup.sh (sets PYTHONPATH automatically)
source setup.sh

# Option 2: Set PYTHONPATH manually
export PYTHONPATH="$PWD/python:$PYTHONPATH"
```
