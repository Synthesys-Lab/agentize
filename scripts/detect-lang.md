# detect-lang.sh

Compatibility wrapper for project language detection.

## External Interface

### ./scripts/detect-lang.sh <project_path>

Writes the detected language to stdout and returns a non-zero exit code when
unable to detect a language.

## Internal Helpers

Delegates to `_lol_detect_lang()` after sourcing `src/cli/lol.sh`.
