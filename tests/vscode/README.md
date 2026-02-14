# VS Code Extension Tests

This folder contains shell-based checks for the VS Code extension, covering
webview UI expectations, link handling, and plan execution helpers.

## Organization

- `test-link-detection.sh` validates the log link regex handling in the webview.
- `test-plan-view-ui.sh` validates webview UI structure and documentation.
- `test-plan-refine.sh` validates refinement wiring for the Plan view.
- `test-step-progress-parser.sh` validates step progress parsing for plan logs.
