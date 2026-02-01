# helpers.sh

## Purpose

Helper functions for `acw` including validation utilities and chat session
management. All functions prefixed with `_acw_` to prevent tab-completion
pollution.

## Validation Helpers

### _acw_validate_args()
Validates required CLI arguments (cli, model, input, output).

### _acw_check_cli()
Checks if the provider CLI binary exists in PATH.

### _acw_ensure_output_dir()
Creates the output file's parent directory if it doesn't exist.

### _acw_check_input_file()
Verifies that the input file exists and is readable.

## Chat Session Helpers

### _acw_chat_session_dir()
Returns `$AGENTIZE_HOME/.tmp/acw-sessions` and ensures the directory exists.

### _acw_chat_session_path <session-id>
Resolves a session ID to `<dir>/<id>.md`.

### _acw_chat_generate_session_id()
Generates an 8-character base62 ID using `/dev/urandom`. Retries on collision.

### _acw_chat_validate_session_id <id>
Validates base62 characters (a-z, A-Z, 0-9) and length 8-12. Returns non-zero
on failure.

### _acw_chat_create_session <path> <provider> <model>
Writes YAML front matter with `provider`, `model`, and `created` (UTC ISO-8601).

### _acw_chat_validate_session_file <path>
Checks that file exists, begins with `---`, ends header with `---`, and contains
required keys (provider, model, created).

### _acw_chat_prepare_input <session-file> <input-file> <combined-out>
Prepares combined input for the provider:
1. Copy session file to combined temp file.
2. Append `---` separator if session already has turns.
3. Append `# User` header and user input content.
4. Return combined file path.

### _acw_chat_append_turn <session-file> <user-file> <assistant-file>
Appends a turn to the session file:
1. Decide if a separator is needed (session has existing `# User`).
2. Append separator if needed.
3. Append `# User` + user content.
4. Append `# Assistant` + assistant content.
5. Ensure trailing newline.

### _acw_chat_list_sessions()
Lists `*.md` files in session dir and prints `id`, `provider`, `model`, `created`
(best-effort from header).
