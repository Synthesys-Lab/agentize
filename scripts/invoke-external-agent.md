# invoke-external-agent.sh

Unified external agent invocation wrapper providing a single source of truth for agent routing logic.

## Purpose

This script consolidates the three-tier fallback logic (Codex -> Agent CLI -> Claude) into a single location, eliminating duplication across Python and shell components.

## Interface

```bash
./invoke-external-agent.sh <agent> <input_file> <output_file>
```

**Arguments:**
- `agent` - Agent selection: `auto`, `codex`, `agent`, `claude`
- `input_file` - Path to input prompt file
- `output_file` - Path to output response file

**Environment:**
- `AGENTIZE_EXTERNAL_AGENT` - Override agent selection (takes precedence over argument)

## Agent Routing Logic

| AGENTIZE_EXTERNAL_AGENT | Behavior |
|-------------------------|----------|
| `auto` (default) | Try codex -> try agent -> use claude (three-tier fallback) |
| `codex` | Force codex; error if unavailable |
| `agent` | Force agent CLI; error if unavailable |
| `claude` | Force claude; error if unavailable |
| invalid | Exit with error message |

## Exit Codes

- `0` - Success
- `1` - Agent unavailable or invalid configuration
- `2` - Input file missing or invalid arguments

## Usage

### Direct invocation

```bash
# Use auto-detection (three-tier fallback)
./scripts/invoke-external-agent.sh auto input.md output.txt

# Force specific agent
AGENTIZE_EXTERNAL_AGENT=claude ./scripts/invoke-external-agent.sh auto input.md output.txt
```

### From shell scripts

```bash
# Source and call
scripts/invoke-external-agent.sh "$MODEL" "$INPUT_FILE" "$OUTPUT_FILE"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Agent invocation failed" >&2
    exit 1
fi
```

### From Python

```python
import subprocess
import os

result = subprocess.run(
    ['scripts/invoke-external-agent.sh', 'auto', input_path, output_path],
    env={**os.environ, 'AGENTIZE_EXTERNAL_AGENT': os.getenv('AGENTIZE_EXTERNAL_AGENT', 'auto')},
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print(f"Agent invocation failed: {result.stderr}")
```

## Used By

- `.claude-plugin/skills/external-consensus/scripts/external-consensus.sh`
- `.opencode/skills/external-consensus/scripts/external-consensus.sh`
- `.claude-plugin/lib/workflow.py` (via subprocess)

## Agent-Specific Configuration

### Codex
- Model: `gpt-5.2-codex`
- Sandbox: read-only
- Web search: enabled
- Reasoning effort: xhigh

### Agent CLI
- Piped input via `agent -p`
- Combined stdout/stderr output

### Claude
- Model: opus
- Tools: Read, Grep, Glob, WebSearch, WebFetch (read-only)
- Permission mode: bypassPermissions
