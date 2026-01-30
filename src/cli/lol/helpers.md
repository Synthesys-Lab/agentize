# helpers.sh

Utility functions used by the `lol` CLI modules.

## External Interface

None. This module is private and is sourced by `lol.sh`.

## Internal Helpers

### _lol_detect_lang()

Detects a project's language based on common file markers.

**Parameters**:
- `project_path`: Path to the project root.

**Output**:
- Writes `python`, `c`, or `cxx` to stdout when detected.
- Returns `0` on success, `1` when detection fails.

The detection favors explicit project files (e.g., `pyproject.toml`,
`requirements.txt`, or `CMakeLists.txt`) to avoid slow directory scans.
