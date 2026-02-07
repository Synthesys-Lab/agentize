# test-acw-kimi-stripper.sh

## Purpose

Validate Kimi stream-json output is stripped into plain assistant text for file and chat modes.

## Test Cases

### ndjson_stripping
**Purpose**: NDJSON output is concatenated into plain text.
**Expected**: Output file contains combined text fragments.

### json_payload_stripping
**Purpose**: Single JSON payload yields plain text.
**Expected**: Output file contains the extracted text content.

### mixed_line_stripping
**Purpose**: Mixed non-JSON lines do not break stripping.
**Expected**: Output ignores non-JSON lines and keeps extracted text.

### chat_session_stripping
**Purpose**: Chat sessions store stripped assistant text for Kimi turns.
**Expected**: Session file and output file contain plain text without raw JSON.

### skill_usage_stripping
**Purpose**: Skill/tool messages (role=tool) are filtered out, only assistant text is kept.
**Expected**: Output contains assistant text before and after skill usage, but not tool results or system tags.
