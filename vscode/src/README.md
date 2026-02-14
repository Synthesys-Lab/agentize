# Extension Backend

This folder hosts the VS Code extension backend modules for the Plan sidebar.

## Organization

- `extension.ts` registers the webview provider and extension entry points.
- `state/` defines Plan state types and persistence helpers.
- `runner/` executes plan commands and emits run events.
- `view/` renders the webview HTML and bridges messages.
