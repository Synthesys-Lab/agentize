# Module: agentize.workflow.utils

Reusable TTY output helpers and shell invocation utilities for workflow orchestration.

## Purpose

This module extracts terminal handling and `acw` shell invocation from the planner pipeline, making them available for reuse across different workflow implementations.

## Exports

### `PlannerTTY`

```python
class PlannerTTY:
    def __init__(self, *, verbose: bool = False) -> None: ...
    def term_label(self, label: str, text: str, style: str = "") -> None: ...
    def print_feature(self, desc: str) -> None: ...
    def stage(self, message: str) -> None: ...
    def log(self, message: str) -> None: ...
    def timer_start(self) -> float: ...
    def timer_log(self, stage: str, start_epoch: float, backend: str | None = None) -> None: ...
    def anim_start(self, label: str) -> None: ...
    def anim_stop(self) -> None: ...
```

TTY output helper that provides terminal styling, dot animations, and timing logs with environment-based feature gates.

**Constructor:**
- `verbose`: When `True`, enables verbose logging via `log()` method

**Environment gates:**
- `NO_COLOR`: Disables colored output
- `PLANNER_NO_COLOR`: Disables colored output (planner-specific)
- `PLANNER_NO_ANIM`: Disables dot animations

**Methods:**

| Method | Description |
|--------|-------------|
| `term_label(label, text, style)` | Print styled label with `info` (cyan) or `success` (green) color |
| `print_feature(desc)` | Print feature description with "Feature:" label |
| `stage(message)` | Print stage progress message (always shown) |
| `log(message)` | Print message only when verbose mode enabled |
| `timer_start()` | Return current epoch time for timing |
| `timer_log(stage, start_epoch, backend)` | Log elapsed time since `start_epoch` (include backend when provided) |
| `anim_start(label)` | Start background dot animation with label |
| `anim_stop()` | Stop any running animation and clear line |

### `run_acw`

```python
def run_acw(
    provider: str,
    model: str,
    input_file: str | Path,
    output_file: str | Path,
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
) -> subprocess.CompletedProcess
```

Wrapper around the `acw` shell function that builds and executes an ACW command with quoted paths.

**Parameters:**
- `provider`: Backend provider (`"claude"` or `"codex"`)
- `model`: Model identifier (e.g., `"sonnet"`, `"opus"`)
- `input_file`: Path to input prompt file
- `output_file`: Path for stage output
- `tools`: Tool configuration (Claude provider only)
- `permission_mode`: Permission mode override (Claude provider only)
- `extra_flags`: Additional CLI flags
- `timeout`: Execution timeout in seconds (default: 900)

**Returns:** `subprocess.CompletedProcess` with stdout/stderr captured

**Raises:** `subprocess.TimeoutExpired` if execution exceeds timeout

**Environment:**
- `AGENTIZE_HOME`: Used to locate `acw.sh` script
- `PLANNER_ACW_SCRIPT`: Override path to `acw.sh` (for testing)

## Example

```python
from agentize.workflow.utils import PlannerTTY, run_acw

# TTY output with animation
tty = PlannerTTY(verbose=True)
tty.print_feature("Add user authentication")
start = tty.timer_start()
tty.anim_start("Processing")
# ... do work ...
tty.anim_stop()
tty.timer_log("auth-stage", start, "claude:sonnet")

# Direct acw invocation
result = run_acw(
    "claude", "sonnet",
    "input.md", "output.md",
    tools="Read,Grep,Glob",
)
```

## Design Rationale

- **Extraction point**: These utilities were extracted from `planner.py` to enable reuse without importing the full pipeline orchestration code.
- **Environment parity**: Uses the same environment gates (`NO_COLOR`, `PLANNER_NO_COLOR`, `PLANNER_NO_ANIM`) as the shell planner for consistent behavior.
- **Thread safety**: `PlannerTTY` uses daemon threads for animation, ensuring clean shutdown.
