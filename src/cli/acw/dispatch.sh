#!/usr/bin/env bash
# acw CLI main dispatcher
# Entry point and help text

# Print usage information
_acw_usage() {
    cat <<'EOF'
acw: Agent CLI Wrapper

Unified file-based interface for invoking AI CLI tools.

Usage:
  acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]
  acw --complete <topic>
  acw --help

Arguments:
  cli-name      Provider: claude, codex, opencode, cursor
  model-name    Model identifier for the provider
  input-file    Path to file containing the prompt (unless --editor is used)
  output-file   Path where response will be written (unless --stdout is used)

Options:
  --editor      Use $EDITOR to compose the input prompt
  --stdout      Write output to stdout and merge provider stderr into stdout
  --complete    Print completion values for a topic
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
  acw --editor claude claude-sonnet-4-20250514 response.txt
  acw --stdout claude claude-sonnet-4-20250514 prompt.txt
EOF
}

# Validate provider options do not include unexpected positional arguments.
# Allows option values after flags and allows positional values after `--`.
_acw_validate_no_positional_args() {
    local context="$1"
    shift
    local expect_value="false"
    local arg=""

    for arg in "$@"; do
        if [ "$arg" = "--" ]; then
            return 0
        fi

        if [ "$expect_value" = "true" ]; then
            expect_value="false"
            continue
        fi

        case "$arg" in
            -*)
                expect_value="true"
                ;;
            *)
                echo "Error: Unexpected positional argument '$arg'." >&2
                echo "Remove the extra value or pass provider options after '--'." >&2
                echo "Context: $context" >&2
                return 1
                ;;
        esac
    done

    return 0
}

# Main acw function
acw() {
    local use_editor=0
    local stdout_mode=0

    # Parse acw flags before cli-name
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                _acw_usage
                return 0
                ;;
            --complete)
                _acw_complete "$2"
                return 0
                ;;
            --editor)
                use_editor=1
                shift
                ;;
            --stdout)
                stdout_mode=1
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Error: Unknown acw flag '$1'." >&2
                echo "Use --help for usage. acw flags must appear before cli-name." >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Parse arguments
    local cli_name="$1"
    local model_name="$2"

    # Show usage if no arguments
    if [ -z "$cli_name" ]; then
        _acw_usage >&2
        return 1
    fi

    if [ -z "$model_name" ]; then
        echo "Error: Missing model-name argument" >&2
        echo "" >&2
        echo "Usage: acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]" >&2
        return 1
    fi

    shift 2

    local input_file=""
    local output_file=""
    local editor_tmp=""

    if [ "$use_editor" -eq 0 ]; then
        input_file="$1"
        if [ -z "$input_file" ]; then
            echo "Error: Missing input-file argument" >&2
            echo "" >&2
            echo "Usage: acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]" >&2
            return 1
        fi
        shift
    fi

    if [ "$stdout_mode" -eq 0 ]; then
        output_file="$1"
        if [ -z "$output_file" ]; then
            echo "Error: Missing output-file argument" >&2
            echo "" >&2
            echo "Usage: acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]" >&2
            return 1
        fi
        shift
    fi

    if [ "$use_editor" -eq 1 ] || [ "$stdout_mode" -eq 1 ]; then
        local positional_context="editor/stdout mode"
        if [ "$use_editor" -eq 1 ] && [ "$stdout_mode" -eq 1 ]; then
            positional_context="--editor and --stdout do not accept input-file or output-file"
        elif [ "$use_editor" -eq 1 ]; then
            positional_context="--editor cannot be used with input-file"
        elif [ "$stdout_mode" -eq 1 ]; then
            positional_context="--stdout cannot be used with output-file"
        fi

        if ! _acw_validate_no_positional_args "$positional_context" "$@"; then
            return 1
        fi
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

    # Handle --editor flag
    if [ "$use_editor" -eq 1 ]; then
        if [ -z "$EDITOR" ]; then
            echo "Error: \$EDITOR is not set." >&2
            echo "Set the EDITOR environment variable to use --editor." >&2
            return 1
        fi

        editor_tmp=$(mktemp)
        if [ -z "$editor_tmp" ]; then
            echo "Error: Failed to create temporary input file." >&2
            return 1
        fi

        trap 'rm -f "$editor_tmp"' EXIT INT TERM

        if ! "$EDITOR" "$editor_tmp"; then
            echo "Error: Editor exited with non-zero status." >&2
            rm -f "$editor_tmp"
            trap - EXIT INT TERM
            return 1
        fi

        local editor_content=""
        editor_content=$(cat "$editor_tmp")
        local trimmed=""
        trimmed=$(echo "$editor_content" | tr -d '[:space:]')
        if [ -z "$trimmed" ]; then
            echo "Error: Editor content is empty." >&2
            echo "Write content in the editor to provide input." >&2
            rm -f "$editor_tmp"
            trap - EXIT INT TERM
            return 1
        fi

        input_file="$editor_tmp"
    fi

    # Handle --stdout flag
    if [ "$stdout_mode" -eq 1 ]; then
        output_file="/dev/stdout"
    fi

    # Check if input file exists
    if ! _acw_check_input_file "$input_file"; then
        if [ -n "$editor_tmp" ]; then
            rm -f "$editor_tmp"
            trap - EXIT INT TERM
        fi
        return 3
    fi

    # Ensure output directory exists
    if [ "$stdout_mode" -eq 0 ]; then
        if ! _acw_ensure_output_dir "$output_file"; then
            if [ -n "$editor_tmp" ]; then
                rm -f "$editor_tmp"
                trap - EXIT INT TERM
            fi
            return 1
        fi
    fi

    # Check if CLI binary exists
    if ! _acw_check_cli "$cli_name"; then
        if [ -n "$editor_tmp" ]; then
            rm -f "$editor_tmp"
            trap - EXIT INT TERM
        fi
        return 4
    fi

    # Remaining arguments are provider options
    local provider_exit=0

    # Dispatch to provider function
    case "$cli_name" in
        claude)
            if [ "$stdout_mode" -eq 1 ]; then
                _acw_invoke_claude "$model_name" "$input_file" "$output_file" "$@" 2>&1
            else
                _acw_invoke_claude "$model_name" "$input_file" "$output_file" "$@"
            fi
            provider_exit=$?
            ;;
        codex)
            if [ "$stdout_mode" -eq 1 ]; then
                _acw_invoke_codex "$model_name" "$input_file" "$output_file" "$@" 2>&1
            else
                _acw_invoke_codex "$model_name" "$input_file" "$output_file" "$@"
            fi
            provider_exit=$?
            ;;
        opencode)
            if [ "$stdout_mode" -eq 1 ]; then
                _acw_invoke_opencode "$model_name" "$input_file" "$output_file" "$@" 2>&1
            else
                _acw_invoke_opencode "$model_name" "$input_file" "$output_file" "$@"
            fi
            provider_exit=$?
            ;;
        cursor)
            if [ "$stdout_mode" -eq 1 ]; then
                _acw_invoke_cursor "$model_name" "$input_file" "$output_file" "$@" 2>&1
            else
                _acw_invoke_cursor "$model_name" "$input_file" "$output_file" "$@"
            fi
            provider_exit=$?
            ;;
    esac

    if [ -n "$editor_tmp" ]; then
        rm -f "$editor_tmp"
        trap - EXIT INT TERM
    fi

    return "$provider_exit"
}
