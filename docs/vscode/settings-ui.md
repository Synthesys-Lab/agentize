# Settings UI (VS Code)

The Settings tab in the VS Code extension provides a lightweight way to configure
Agentize backend defaults without leaving the editor.

## Goals

- Make backend configuration discoverable for new users in the extension.
- Separate project metadata from developer-specific settings.
- Keep the UX focused on the `provider:model` pairing that the CLI expects.

## Scope and Files

The UI mirrors the existing configuration hierarchy:

- `.agentize.yaml` is shown as **read-only** project metadata.
- `.agentize.local.yaml` (repo) stores developer-specific settings for the current project.
- `~/.agentize.local.yaml` (global) stores user-wide defaults used across repositories.

Only `planner.backend` is edited directly in the Settings UI. All other YAML keys
remain untouched.

## Backend Format

Backends are stored as `provider:model` strings. The UI constrains providers to the
common list (`claude`, `openai`, `codex`, `cursor`, `kimi`) while leaving the model
field free-form to support new releases without UI updates.

## Workflow

1. Open the Settings tab in the Agentize Activity Bar view.
2. Choose a provider and model for either the repo or global scope.
3. Save to write `planner.backend` into the selected `.agentize.local.yaml` file.
4. Plan runs read backends from YAML; implementation runs reuse the same value for
   `lol impl --backend` when available.

## Data Flow

- The webview requests settings snapshots from the extension host.
- The extension reads YAML files directly (no AST parsing) and extracts `planner.backend`.
- Save actions update or insert the `planner.backend` key while preserving other content.

## Limitations

- YAML comments may be lost if the file is rewritten around `planner.backend`.
- The UI does not visualize inheritance; each scope displays its own file contents.
