#!/bin/bash
# PostToolUse Hook - Auto-format files after Edit/Write operations
#
# Purpose: Automatically format edited files based on extension.
# Behavior: Non-blocking (exit 0 always) - formatting failures are logged.
#
# Reference: https://docs.anthropic.com/en/docs/claude-code/hooks

# Read tool input from stdin (JSON format)
input=$(cat)

# Check jq availability upfront (required for JSON parsing)
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, hook features limited" >&2
  exit 0
fi

# Extract file_path from tool_input using jq
# Handle both Edit and Write tool formats, with fallback to tool_response.filePath
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

# Skip if no file path (shouldn't happen, but defensive)
if [ -z "$file_path" ]; then
  exit 0
fi

# Skip if file doesn't exist (may have been deleted)
if [ ! -f "$file_path" ]; then
  exit 0
fi

# Format based on file extension (all non-blocking)
case "$file_path" in
  *.py)
    # Python: Use black formatter
    if command -v black &> /dev/null; then
      black --quiet "$file_path" || echo "Warning: black formatting failed for $file_path" >&2
    fi
    ;;
  *.cpp|*.hpp|*.h|*.cc)
    # C++: Use clang-format
    if command -v clang-format &> /dev/null; then
      clang-format -i "$file_path" || echo "Warning: clang-format failed for $file_path" >&2
    fi
    ;;
  *.md)
    # Markdown: No auto-formatting (preserve intentional formatting)
    ;;
  *.json)
    # JSON: Skipped (avoid disrupting intentional formatting like settings.json)
    ;;
  *)
    # Unknown extension: skip formatting
    ;;
esac

exit 0
