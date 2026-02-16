# skeleton.html

Shared skeleton markup for the Plan webview shell.

## External Interface

### Placeholder contract
- `{{SKELETON_ERROR}}` is replaced by the host runtime.
- In VS Code runtime, `planViewProvider.ts` injects an asset-missing message when needed.
- In harness runtime, the placeholder is replaced with an empty string.

## Internal Helpers

### Shared shell intent
Keeping this skeleton in one file avoids drift between:
- VS Code webview boot rendering.
- Standalone harness rendering used for Playwright screenshots.
