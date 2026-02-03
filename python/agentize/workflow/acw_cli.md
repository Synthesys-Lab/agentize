# Module: agentize.workflow.acw_cli

CLI wrapper for running a single ACW execution from shell workflows.

## External Interface

### Command

```bash
python -m agentize.workflow.acw_cli \
  --name <label> \
  --provider <provider> \
  --model <model> \
  --input <input-file> \
  --output <output-file> \
  [--timeout <seconds>] \
  [--tools <tool-spec>] \
  [--permission-mode <mode>] \
  [--yolo]
```

**Parameters:**
- `--name`: Label used in ACW start/finish logs.
- `--provider`: Provider name validated via `acw --complete providers`.
- `--model`: Provider-specific model identifier.
- `--input`: Path to the prompt file.
- `--output`: Path to write the response.
- `--timeout`: Execution timeout in seconds (default: 900).
- `--tools`: Tool configuration (Claude provider only).
- `--permission-mode`: Permission mode override (Claude provider only).
- `--yolo`: Pass `--yolo` through to the provider CLI.

**Behavior:**
- Validates the provider using the shared ACW provider list.
- Emits start/finish timing logs.
- Invokes `run_acw` with the supplied arguments.

**Exit codes:**
- `0`: Completed successfully.
- `1`: Invalid arguments or runtime errors.

## Internal Helpers

### _parse_args()
Builds the CLI argument parser and returns parsed arguments.

### _build_acw()
Constructs an `ACW` instance using parsed arguments and applies optional flags.
