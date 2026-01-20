#!/usr/bin/env bash
# acw provider functions
# Provider-specific invocation functions for the Agent CLI Wrapper
#
# I/O Behavior:
#   - All functions write model output to the specified output file
#   - stderr is passed through to the caller (for progress messages, diagnostics)
#   - This allows callers to display real-time progress while capturing results

# Invoke Claude CLI
# Usage: acw_invoke_claude <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: claude exit code
acw_invoke_claude() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Claude uses -p @file for input, output to stdout
    # stderr passes through for progress messages
    claude --model "$model" -p "@$input" "$@" > "$output"
}

# Invoke Codex CLI
# Usage: acw_invoke_codex <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: codex exit code
acw_invoke_codex() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Codex reads from stdin, uses -o for output file
    # stderr passes through for progress messages
    codex exec --model "$model" -o "$output" "$@" - < "$input"
}

# Invoke Opencode CLI (best-effort)
# Usage: acw_invoke_opencode <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: opencode exit code
acw_invoke_opencode() {
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
# Usage: acw_invoke_cursor <model> <input> <output> [options...]
# I/O: stdout -> output file, stderr -> passthrough (progress messages visible)
# Returns: agent exit code
acw_invoke_cursor() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Cursor uses 'agent' binary - best effort, may need adjustment
    # Assuming stdin/stdout pattern
    # stderr passes through for progress messages
    agent --model "$model" "$@" < "$input" > "$output"
}
