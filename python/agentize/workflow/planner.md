# DEPRECATED: planner.py

This file is deprecated and will be removed. It exists only for backward compatibility.

## New Locations

- **Pipeline orchestration**: `agentize.workflow.planner` package (`planner/__main__.py`)
- **TTY utilities**: `agentize.workflow.utils` module (`utils.py`)

## Migration

Replace imports:

```python
# OLD (deprecated)
from agentize.workflow.planner import run_planner_pipeline, StageResult, PlannerTTY, run_acw

# NEW (preferred)
from agentize.workflow import run_planner_pipeline, StageResult, PlannerTTY, run_acw

# Or from specific modules
from agentize.workflow.utils import PlannerTTY, run_acw
from agentize.workflow.planner import run_planner_pipeline, StageResult
```

## CLI Invocation

The planner can now be invoked as a runnable package:

```bash
python -m agentize.workflow.planner --feature-desc "Add dark mode" --issue-mode true
```
