# VS Code Extension Agent Notes

Run all commands with `cwd` in the `vscode/` folder.

## Build

To build this plugin, run:

```bash
make build
```

## Test

All the frontend tests are in `vscode/test/playwright/`.
All the playwright tests are "soft", which means they will not automatically be triggered
by `make test` and you have to run them manually.
When a new feature is implemented, add a test for it in the `playwright` folder.
