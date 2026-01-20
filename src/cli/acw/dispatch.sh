#!/usr/bin/env bash
# acw CLI main dispatcher
# Entry point and help text

# Print usage information
_acw_usage() {
    cat <<'EOF'
acw: Agent CLI Wrapper

Unified file-based interface for invoking AI CLI tools.

Usage:
  acw <cli-name> <model-name> <input-file> <output-file> [options...]
  acw --help

Arguments:
  cli-name      Provider: claude, codex, opencode, cursor
  model-name    Model identifier for the provider
  input-file    Path to file containing the prompt
  output-file   Path where response will be written

Options:
  --help        Show this help message
  [options...]  Additional options passed to the provider CLI

Providers:
  claude        Anthropic Claude CLI (full support)
  codex         OpenAI Codex CLI (full support)
  opencode      Opencode CLI (best-effort)
  cursor        Cursor Agent CLI (best-effort)

Exit Codes:
  0   Success
  1   Missing required arguments
  2   Unknown provider
  3   Input file not found or not readable
  4   Provider CLI binary not found
  127 Provider execution failed

Examples:
  acw claude claude-sonnet-4-20250514 prompt.txt response.txt
  acw codex gpt-4o prompt.txt response.txt
  acw claude claude-sonnet-4-20250514 prompt.txt response.txt --max-tokens 4096
EOF
}

# Main acw function
acw() {
    # Handle --help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        _acw_usage
        return 0
    fi

    # Parse arguments
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    # Show usage if no arguments
    if [ -z "$cli_name" ]; then
        _acw_usage >&2
        return 1
    fi

    # Validate required arguments
    if ! acw_validate_args "$cli_name" "$model_name" "$input_file" "$output_file"; then
        echo "" >&2
        echo "Usage: acw <cli-name> <model-name> <input-file> <output-file> [options...]" >&2
        return 1
    fi

    # Check if provider is known
    case "$cli_name" in
        claude|codex|opencode|cursor)
            # Valid provider
            ;;
        *)
            echo "Error: Unknown provider '$cli_name'" >&2
            echo "Supported providers: claude, codex, opencode, cursor" >&2
            return 2
            ;;
    esac

    # Check if input file exists
    if ! acw_check_input_file "$input_file"; then
        return 3
    fi

    # Ensure output directory exists
    if ! acw_ensure_output_dir "$output_file"; then
        return 1
    fi

    # Check if CLI binary exists
    if ! acw_check_cli "$cli_name"; then
        return 4
    fi

    # Shift past the four required arguments
    shift 4

    # Dispatch to provider function
    case "$cli_name" in
        claude)
            acw_invoke_claude "$model_name" "$input_file" "$output_file" "$@"
            ;;
        codex)
            acw_invoke_codex "$model_name" "$input_file" "$output_file" "$@"
            ;;
        opencode)
            acw_invoke_opencode "$model_name" "$input_file" "$output_file" "$@"
            ;;
        cursor)
            acw_invoke_cursor "$model_name" "$input_file" "$output_file" "$@"
            ;;
    esac
}
