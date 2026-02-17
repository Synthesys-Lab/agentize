# index.ts

Webview script that renders a minimal Settings launcher UI.

## VS Code API Lifecycle

The unified webview page can host multiple panel scripts in one document.
This module uses a shared `globalThis.__agentizeVsCodeApi__` handle so VS Code
webview API acquisition remains single-instance for the page lifecycle.

## External Interface

### UI Rendering
- Replaces `#settings-root` with three file links:
  - `Metadata: .agentize.yaml`
  - `Repo Local: .agentize.local.yaml`
  - `User Local: ~/.agentize.local.yaml`
- Keeps path labels short and stable instead of rendering absolute filesystem paths.
- Uses a status line for quick open feedback.

### Webview Messages
Sends messages:
- `link/openFile` with:
  - `path`: selected settings path.
  - `createIfMissing: true`: request creation of missing files before opening.

## Internal Helpers

### settingsLinks
Static metadata describing the three file links shown in the panel.
