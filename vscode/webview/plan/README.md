# Plan Tab UI

This folder provides the Plan Activity Bar UI implementation for the webview.

## Organization

- `index.ts` renders sessions, handles input, and posts messages. It is compiled to `out/index.js`
  for the webview runtime.
- `types.ts` defines message shapes used by the plan webview.
- `styles.css` defines the minimal readable styling for the Plan tab.
