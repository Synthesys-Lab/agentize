# providers.sh

## Purpose

Provider-specific invocation functions for `acw`. Each function adapts the
file-based input/output contract to a provider CLI while keeping stderr
passthrough for progress messages.

## External Interface

These functions are internal to the `acw` module (prefixed with `_acw_`) but
serve as the provider invocation surface for the dispatcher.

### _acw_invoke_claude <model> <input> <output> [options...]
- Reads the prompt from `input` and writes the response to `output`.
- Normalizes `--yolo` to `--dangerously-skip-permissions`.
- Returns the Claude CLI exit code.

### _acw_invoke_codex <model> <input> <output> [options...]
- Reads the prompt from `input` via stdin and writes the response to `output`.
- Returns the Codex CLI exit code.

### _acw_invoke_opencode <model> <input> <output> [options...]
- Reads the prompt from `input` via stdin and writes the response to `output`.
- Returns the Opencode CLI exit code.

### _acw_invoke_cursor <model> <input> <output> [options...]
- Reads the prompt from `input` via stdin and writes the response to `output`.
- Returns the Cursor/Agent CLI exit code.

### _acw_invoke_kimi <model> <input> <output> [options...]
- Runs Kimi in print mode for non-interactive execution.
- Forces `--output-format stream-json` to normalize streaming output.
- Reads the prompt from `input` via stdin and writes the response to `output`.
- Ignores the `model` argument and lets Kimi select its default model.
- Returns the Kimi CLI exit code.

### _acw_invoke_gemini <model> <input> <output> [options...]
- Runs Gemini CLI in non-interactive mode with `-p` flag for prompt input.
- Forces `--output-format stream-json` to normalize streaming output.
- Reads the prompt from `input` via `-p "$(cat "$input")"` and writes to `output`.
- Ignores the `model` argument and lets Gemini select its default model.
- Passes `--yolo` through natively (no translation needed).
- Returns the Gemini CLI exit code.

## Internal Helpers

None. Each provider function encapsulates its own CLI-specific invocation.
