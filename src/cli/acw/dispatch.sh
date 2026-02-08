#!/usr/bin/env bash
# acw CLI main dispatcher
# Entry point and help text

# Log version information to stderr
_acw_log_version() {
    local git_dir="${AGENTIZE_HOME:-.}"
    local branch="unknown"
    local hash="unknown"

    if command -v git >/dev/null 2>&1; then
        branch=$(git -C "$git_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        hash=$(git -C "$git_dir" rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
    fi

    echo "[agentize] $branch @$hash" >&2
}

# Print usage information
_acw_usage() {
    _acw_log_version
    cat <<'EOF'
acw: Agent CLI Wrapper

Unified file-based interface for invoking AI CLI tools.

Usage:
  acw [--chat [session-id]] [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]
  acw --chat-list
  acw --complete <topic>
  acw --help

Arguments:
  cli-name      Provider: claude, codex, opencode, cursor, kimi, gemini
  model-name    Model identifier for the provider
  input-file    Path to file containing the prompt (unless --editor is used)
  output-file   Path where response will be written (unless --stdout is used)

Options:
  --chat        Start or continue a chat session
  --chat-list   List available chat sessions
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
  kimi          Kimi CLI (best-effort)
  gemini        Gemini CLI (best-effort)

Exit Codes:
  0   Success
  1   Missing required arguments
  2   Unknown provider
  3   Input file not found or not readable
  4   Provider CLI binary not found
  5   Chat session error (invalid id, missing file, or format error)
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

# Strip Kimi stream-json output into plain assistant text.
# Usage: _acw_kimi_strip_output <input> <output>
_acw_kimi_strip_output() {
    local input="$1"
    local output="$2"

    if ! command -v python >/dev/null 2>&1; then
        echo "Error: python is required to strip Kimi output." >&2
        /bin/cat "$input" > "$output"
        return 1
    fi

    if ! python - "$input" "$output" <<'PY'
import json
import re
import sys

# Pattern to match <system>...</system> blocks (tool call results)
_SYSTEM_TAG_RE = re.compile(r'<system>.*?</system>', re.DOTALL)


def extract_from_content_list(content):
    parts = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get("type") != "text":
            continue
        text = item.get("text")
        if text is None:
            text = item.get("content") or item.get("value")
        if isinstance(text, str):
            # Remove tool call results (wrapped in <system> tags)
            text = _SYSTEM_TAG_RE.sub('', text)
            # Only append if there's meaningful content left
            if text.strip():
                parts.append(text)
    return parts


def extract_text(obj):
    """Extract text from assistant messages, skip tool messages."""
    parts = []
    if isinstance(obj, dict):
        # Skip tool/skill messages entirely
        if obj.get("role") == "tool":
            return parts
        if "content" in obj and isinstance(obj["content"], list):
            parts.extend(extract_from_content_list(obj["content"]))
            for key, value in obj.items():
                if key == "content":
                    continue
                parts.extend(extract_text(value))
        else:
            for value in obj.values():
                parts.extend(extract_text(value))
    elif isinstance(obj, list):
        for item in obj:
            parts.extend(extract_text(item))
    return parts


def parse_json_blob(text):
    try:
        obj = json.loads(text)
    except Exception:
        return [], False
    return extract_text(obj), True


def parse_ndjson(text):
    parts = []
    parsed_any = False
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        parsed_any = True
        parts.extend(extract_text(obj))
    return parts, parsed_any


def main():
    if len(sys.argv) < 3:
        return 1
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    try:
        with open(input_path, "r", encoding="utf-8", errors="replace") as handle:
            raw = handle.read()
    except Exception:
        return 1

    parts, parsed = parse_json_blob(raw.strip())
    if not parsed:
        parts, parsed = parse_ndjson(raw)

    if parsed and parts:
        with open(output_path, "w", encoding="utf-8") as handle:
            handle.write("".join(parts))
        return 0

    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write(raw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY
    then
        /bin/cat "$input" > "$output"
        return 1
    fi

    return 0
}

# Main acw function
acw() {
    local use_editor=0
    local stdout_mode=0
    local chat_mode=0
    local chat_session_id=""

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
            --chat-list)
                _acw_chat_list_sessions
                return 0
                ;;
            --chat)
                chat_mode=1
                shift
                # Check if next arg looks like a session ID (not a flag, not a known provider)
                if [ $# -gt 0 ] && [ "${1:0:1}" != "-" ]; then
                    case "$1" in
                        claude|codex|opencode|cursor|kimi|gemini)
                            # This is the cli-name, not a session ID
                            ;;
                        *)
                            # Assume it's a session ID
                            chat_session_id="$1"
                            shift
                            ;;
                    esac
                fi
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
        claude|codex|opencode|cursor|kimi|gemini)
            # Valid provider
            ;;
        *)
            echo "Error: Unknown provider '$cli_name'" >&2
            echo "Supported providers: claude, codex, opencode, cursor, kimi, gemini" >&2
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

    # Chat mode setup
    local session_file=""
    local combined_input=""
    local chat_output_capture=""
    local original_input_file="$input_file"

    if [ "$chat_mode" -eq 1 ]; then
        # Validate or generate session ID
        if [ -n "$chat_session_id" ]; then
            # Continuing existing session
            if ! _acw_chat_validate_session_id "$chat_session_id"; then
                echo "Error: Invalid session ID '$chat_session_id'" >&2
                echo "Session IDs must be 8-12 base62 characters (a-z, A-Z, 0-9)" >&2
                if [ -n "$editor_tmp" ]; then
                    rm -f "$editor_tmp"
                    trap - EXIT INT TERM
                fi
                return 5
            fi

            session_file=$(_acw_chat_session_path "$chat_session_id")

            if ! _acw_chat_validate_session_file "$session_file"; then
                if [ -n "$editor_tmp" ]; then
                    rm -f "$editor_tmp"
                    trap - EXIT INT TERM
                fi
                return 5
            fi
        else
            # Create new session
            chat_session_id=$(_acw_chat_generate_session_id)
            if [ $? -ne 0 ]; then
                if [ -n "$editor_tmp" ]; then
                    rm -f "$editor_tmp"
                    trap - EXIT INT TERM
                fi
                return 5
            fi

            session_file=$(_acw_chat_session_path "$chat_session_id")
            local session_model="$model_name"
            if [ "$cli_name" = "kimi" ] || [ "$cli_name" = "gemini" ]; then
                session_model="default"
            fi
            _acw_chat_create_session "$session_file" "$cli_name" "$session_model"

            # Print session ID to stderr
            echo "Session: $chat_session_id" >&2
        fi

        # Prepare combined input (session history + new user input)
        combined_input=$(mktemp)
        _acw_chat_prepare_input "$session_file" "$input_file" "$combined_input"
        input_file="$combined_input"

        # For stdout mode in chat, capture output to append to session
        if [ "$stdout_mode" -eq 1 ]; then
            chat_output_capture=$(mktemp)
            output_file="$chat_output_capture"
        fi
    fi

    if [ "$chat_mode" -eq 1 ] && [ "$stdout_mode" -eq 1 ] && [ "$use_editor" -eq 1 ] && [ -t 1 ]; then
        echo "User Prompt:"
        cat "$original_input_file"
        echo ""
        echo "Response:"
    fi

    # Kimi and Gemini write stream-json; capture raw output and strip to plain text afterward.
    local final_output_file="$output_file"
    local provider_output_file="$output_file"
    local stream_json_raw_output=""
    local stream_json_strip=0

    if [ "$cli_name" = "kimi" ] || [ "$cli_name" = "gemini" ]; then
        stream_json_strip=1
        stream_json_raw_output=$(mktemp)
        if [ -z "$stream_json_raw_output" ]; then
            echo "Error: Failed to create temporary output file for stream-json stripping." >&2
            if [ -n "$combined_input" ]; then
                rm -f "$combined_input"
            fi
            if [ -n "$chat_output_capture" ]; then
                rm -f "$chat_output_capture"
            fi
            if [ -n "$editor_tmp" ]; then
                rm -f "$editor_tmp"
                trap - EXIT INT TERM
            fi
            return 1
        fi
        provider_output_file="$stream_json_raw_output"
    fi

    # Remaining arguments are provider options
    local provider_exit=0
    local stderr_file=""
    local stderr_preexist=0

    if [ "$stdout_mode" -eq 0 ]; then
        stderr_file="${final_output_file}.stderr"
    elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
        stderr_file="${session_file%.md}.stderr"
        [ -e "$stderr_file" ] && stderr_preexist=1
    fi

    # Dispatch to provider function
    case "$cli_name" in
        claude)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_claude "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_claude "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_claude "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_claude "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
        codex)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_codex "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_codex "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_codex "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_codex "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
        opencode)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_opencode "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_opencode "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_opencode "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_opencode "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
        cursor)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_cursor "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_cursor "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_cursor "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_cursor "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
        kimi)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_kimi "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_kimi "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_kimi "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_kimi "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
        gemini)
            if [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 0 ]; then
                _acw_invoke_gemini "$model_name" "$input_file" "$provider_output_file" "$@" 2>&1
            elif [ "$stdout_mode" -eq 1 ] && [ "$chat_mode" -eq 1 ]; then
                _acw_invoke_gemini "$model_name" "$input_file" "$provider_output_file" "$@" 2>>"$stderr_file"
            else
                if [ -n "$stderr_file" ]; then
                    _acw_invoke_gemini "$model_name" "$input_file" "$provider_output_file" "$@" 2>"$stderr_file"
                else
                    _acw_invoke_gemini "$model_name" "$input_file" "$provider_output_file" "$@"
                fi
            fi
            provider_exit=$?
            ;;
    esac

    # Clean up empty stderr sidecar if newly created
    if [ -n "$stderr_file" ] && [ "$stderr_preexist" -eq 0 ] && [ ! -s "$stderr_file" ]; then
        rm -f "$stderr_file"
    fi

    if [ "$stream_json_strip" -eq 1 ]; then
        _acw_kimi_strip_output "$provider_output_file" "$final_output_file"
    fi

    # Chat mode cleanup and append turn
    if [ "$chat_mode" -eq 1 ]; then
        if [ "$provider_exit" -eq 0 ]; then
            # Determine assistant response file
            local assistant_response=""
            if [ "$stdout_mode" -eq 1 ]; then
                assistant_response="$final_output_file"
                # Emit captured output to stdout
                cat "$final_output_file"
            else
                assistant_response="$final_output_file"
            fi

            # Append turn to session
            _acw_chat_append_turn "$session_file" "$original_input_file" "$assistant_response"
        fi

        # Clean up temp files
        if [ -n "$combined_input" ]; then
            rm -f "$combined_input"
        fi
        if [ -n "$chat_output_capture" ]; then
            rm -f "$chat_output_capture"
        fi
    fi

    if [ -n "$editor_tmp" ]; then
        rm -f "$editor_tmp"
        trap - EXIT INT TERM
    fi

    if [ -n "$stream_json_raw_output" ]; then
        rm -f "$stream_json_raw_output"
    fi

    return "$provider_exit"
}
