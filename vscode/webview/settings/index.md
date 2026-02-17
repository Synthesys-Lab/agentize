# index.ts

Webview script that renders the Settings UI and manages backend configuration edits.

## External Interface

### UI Rendering
- Replaces `#settings-root` with three sections: `.agentize.yaml` (read-only), repo `.agentize.local.yaml`, and `~/.agentize.local.yaml`.
- Shows provider dropdown and model text input for each editable scope.
- Displays YAML snapshots in read-only `<pre>` blocks for quick context.

### Webview Messages
Sends messages:
- `settings/load`: request settings payload from the extension host.
- `settings/save`: persist a backend update with `{ scope, backend }`.

Receives messages:
- `settings/loaded`: payload with YAML snapshots + backend values for each scope.
- `settings/saved`: payload with updated snapshots after a save.
- `settings/error`: payload with error text (and optional scope) for UI messaging.

### Validation Behavior
- Requires both provider and model before saving.
- Normalizes `provider:model` format for the outgoing `backend` value.
- Injects custom provider options when existing YAML uses an unrecognized provider.

## Internal Helpers

### applySettings(payload)
Maps the incoming snapshots into file path labels, YAML previews, and form fields.

### applyBackend(scope, backend)
Splits `provider:model` strings and updates the provider select + model input.

### saveScope(scope)
Validates input, disables the save button, and posts `settings/save` to the extension host.

### applySnapshot(snapshot, pathEl, contentEl, emptyLabel)
Renders YAML content or an empty-state placeholder when files are missing.
