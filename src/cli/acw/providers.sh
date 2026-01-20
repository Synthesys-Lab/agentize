#!/usr/bin/env bash
# acw provider functions
# Provider-specific invocation functions for the Agent CLI Wrapper

# Invoke Claude CLI
# Usage: acw_invoke_claude <model> <input> <output> [options...]
# Returns: claude exit code
acw_invoke_claude() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Claude uses -p @file for input, output to stdout
    claude --model "$model" -p "@$input" "$@" > "$output"
}

# Invoke Codex CLI
# Usage: acw_invoke_codex <model> <input> <output> [options...]
# Returns: codex exit code
acw_invoke_codex() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Codex reads from stdin, outputs to stdout
    codex --model "$model" "$@" < "$input" > "$output"
}

# Invoke Opencode CLI (best-effort)
# Usage: acw_invoke_opencode <model> <input> <output> [options...]
# Returns: opencode exit code
acw_invoke_opencode() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Opencode interface - best effort, may need adjustment
    # Assuming stdin/stdout pattern similar to codex
    opencode --model "$model" "$@" < "$input" > "$output"
}

# Invoke Cursor/Agent CLI (best-effort)
# Usage: acw_invoke_cursor <model> <input> <output> [options...]
# Returns: agent exit code
acw_invoke_cursor() {
    local model="$1"
    local input="$2"
    local output="$3"
    shift 3

    # Cursor uses 'agent' binary - best effort, may need adjustment
    # Assuming stdin/stdout pattern
    agent --model "$model" "$@" < "$input" > "$output"
}
