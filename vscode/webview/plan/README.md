# Plan Tab UI

This folder provides the Plan Activity Bar UI implementation for the webview.

## Organization

- `index.ts` renders sessions, handles input (including refinement actions), and posts messages including stop requests from the
  plan terminal. It is compiled to `out/index.js`
  for the webview runtime.
- `widgets.ts` implements widget append helpers and widget handle routing for session timelines, including optional stop controls
  in terminal headers.
- `utils.ts` provides shared helpers for step parsing, indicator rendering, and link detection.
- `types.ts` defines message shapes used by the plan webview.
- `styles.css` defines the minimal readable styling for the Plan tab.
- `skeleton.html` defines shared boot skeleton markup consumed by both VS Code webview HTML and the screenshot harness.
