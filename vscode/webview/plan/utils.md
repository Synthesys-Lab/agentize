# utils.ts

Shared helpers for Plan webview rendering, step tracking, and log parsing.

## External Interface

### StepState
Tracks progress for a single stage indicator.

**Fields**:
- `stage`: Stage number (1-5).
- `endStage`: End stage for parallel runs (M-N).
- `total`: Total stages (always 5).
- `name`: Agent name parsed from the stage line.
- `provider`: Provider name (for example, `claude`).
- `model`: Model name (for example, `sonnet`).
- `status`: One of `pending`, `running`, or `completed`.
- `startTime`: Timestamp when the stage started.
- `endTime`: Timestamp when the stage completed.

### parseStageLine(line, at?)
Parses stderr stage lines like `Stage 2/5: Running ...` and returns a `StepState` seeded with start time.
Returns `null` when the line does not match the expected format.
`at` lets callers provide a persisted timestamp instead of using `Date.now()`.

### updateStepStatesIn(stateMap, sessionId, line, at?)
Updates the step state list for a session key by marking any running step as completed and
adding the new running step parsed from `line`. Returns `true` when a new step is added.
`at` lets callers complete/start stages using a specific timestamp.

### completeAllStepsIn(stateMap, sessionId)
Marks all running steps for the given session key as completed, recording end times.

### completeAllStepsInAt(stateMap, sessionId, at)
Marks all running steps as completed using an explicit completion timestamp.

### formatElapsed(startTime, endTime)
Formats elapsed time as a rounded seconds string like `"12s"`.

### escapeHtml(text)
Escapes HTML special characters for safe insertion into `innerHTML`.

### renderStepIndicatorsFrom(stateMap, sessionId, className?)
Builds and returns a DOM container with step indicators for the given session key.
Uses `className` when provided; defaults to `step-indicators`.

### renderLinks(text)
Converts GitHub issue URLs and local `.tmp/*.md` paths in a log line into clickable links
for the webview message handlers.

### extractIssueNumber(line)
Extracts an issue number from placeholder creation logs or GitHub issue URLs.

## Internal Helpers

All helpers in this module are exported to keep the webview logic testable and reusable.
