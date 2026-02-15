# worktreeViewProvider.ts

Webview view provider that renders the Worktree Activity Bar panel with a static
placeholder layout.

## External Interface

### WorktreeViewProvider
- `resolveWebviewView(view: vscode.WebviewView)`: configures the webview options,
  injects the Worktree HTML shell, and loads the compiled webview assets.

## Internal Helpers

### buildHtml(webview: vscode.Webview)
Builds the CSP-safe HTML shell, including the Worktree CSS and compiled script.
The HTML includes a small skeleton card that keeps the view readable while assets
load or when they are missing.

### getNonce()
Generates a random nonce for the CSP `script-src` directive so the inline
bootstrap script can safely load the Worktree module.
