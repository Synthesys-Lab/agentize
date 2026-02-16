# VS Code Extension Agent Notes

Run all commands with `cwd` in the `vscode/` folder.

## Build

To build this plugin, run:

```bash
make build
```

## Playwright Render Screenshot to `.tmp`

To test the frontend rendering, use Playwright.

```bash
npm install --save-dev playwright
```

Capture a rendering screenshot into repo-level `.tmp`:

```bash
mkdir -p ../.tmp
npx playwright screenshot \
  "file://$PWD/webview/plan/dev-harness.html" \
  "../.tmp/plan-render-$(date +%Y%m%d-%H%M%S).png"
```

If your render target is not `dev-harness.html`, replace the URL with your target page URL.

## Check Latest Render Figure in `.tmp`

Print the latest screenshot path:

```bash
ls -t ../.tmp/plan-render-*.png | head -n 1
```

Then open that image in your viewer, or pass the absolute path to Codex for image analysis.
