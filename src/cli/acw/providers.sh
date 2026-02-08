#!/usr/bin/env bash
# acw provider functions
# Provider-specific invocation functions for the Agent CLI Wrapper
#
# I/O Behavior:
#   - All functions write model output to the specified output file
#   - stderr is passed through to the caller (for progress messages, diagnostics)
#   - This allows callers to display real-time progress while capturing results

# Invoke Claude CLI
# Usage: _acw_invoke_claude <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: claude exit code
_acw_invoke_claude() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Normalize --yolo to Claude's supported flag
    local args=()
    for arg in "$@"; do
        if [ "$arg" = "--yolo" ]; then
            args+=( "--dangerously-skip-permissions" )
        else
            args+=( "$arg" )
        fi
    done

    # Claude uses -p @file for input, output to stdout
    # stderr passes through for progress messages
    claude --model "$model" -p "@$input" "${args[@]}" > "$output"
}

# Invoke Codex CLI
# Usage: _acw_invoke_codex <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: codex exit code
_acw_invoke_codex() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Codex reads from stdin, uses -o for output file
    # stderr passes through for progress messages
    codex exec --model "$model" -o "$output" "$@" - < "$input"
}

# Invoke Opencode CLI (best-effort)
# Usage: _acw_invoke_opencode <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: opencode exit code
_acw_invoke_opencode() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Opencode interface - best effort, may need adjustment
    # Assuming stdin/stdout pattern similar to codex
    # stderr passes through for progress messages
    opencode --model "$model" "$@" < "$input" > "$output"
}

# Invoke Cursor/Agent CLI (best-effort)
# Usage: _acw_invoke_cursor <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: agent exit code
_acw_invoke_cursor() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Cursor uses 'agent' binary - best effort, may need adjustment
    # Assuming stdin/stdout pattern
    # stderr passes through for progress messages
    agent --model "$model" "$@" < "$input" > "$output"
}

# Invoke Kimi CLI (best-effort)
# Usage: _acw_invoke_kimi <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: kimi exit code
_acw_invoke_kimi() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Kimi uses print mode for non-interactive runs; prompt is read from stdin.
    # The model argument is ignored so Kimi uses its default model.
    # stderr passes through for progress messages
    kimi --print --output-format stream-json "$@" < "$input" > "$output"
}

# Invoke Gemini CLI (best-effort)
# Usage: _acw_invoke_gemini <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: gemini exit code
_acw_invoke_gemini() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Gemini reads from stdin; model argument is ignored.
    # Outputs plain text by default (unlike Kimi which needs stream-json stripping).
    # stderr passes through for progress messages
    gemini "$@" < "$input" > "$output"
}
