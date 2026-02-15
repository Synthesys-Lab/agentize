import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

export class SettingsViewProvider implements vscode.WebviewViewProvider {
  static readonly viewType = 'agentize.settingsView';

  constructor(private readonly extensionUri: vscode.Uri) {}

  resolveWebviewView(view: vscode.WebviewView): void {
    view.webview.options = {
      enableScripts: true,
      localResourceRoots: [vscode.Uri.joinPath(this.extensionUri, 'webview')],
    };

    view.webview.html = this.buildHtml(view.webview);
  }

  private buildHtml(webview: vscode.Webview): string {
    const scriptPath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'settings', 'out', 'index.js');
    const stylePath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'settings', 'styles.css');
    const scriptUri = webview.asWebviewUri(scriptPath);
    const styleUri = webview.asWebviewUri(stylePath);
    const nonce = this.getNonce();
    const scriptFsPath = path.join(this.extensionUri.fsPath, 'webview', 'settings', 'out', 'index.js');
    const styleFsPath = path.join(this.extensionUri.fsPath, 'webview', 'settings', 'styles.css');
    const hasScript = fs.existsSync(scriptFsPath);
    const hasStyle = fs.existsSync(styleFsPath);

    if (!hasScript || !hasStyle) {
      console.warn(
        `[settingsView] missing webview assets: script=${hasScript ? 'ok' : scriptFsPath} style=${hasStyle ? 'ok' : styleFsPath}`,
      );
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; font-src ${webview.cspSource}; style-src ${webview.cspSource} 'unsafe-inline'; script-src ${webview.cspSource} 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="${styleUri}" rel="stylesheet" />
  <title>Agentize Settings</title>
</head>
<body>
  <div id="settings-root" class="settings-root">
    <div class="plan-skeleton">
      <div class="plan-skeleton-title">Settings</div>
      <div id="settings-skeleton-status" class="plan-skeleton-subtitle">Loading webview UI...</div>
      ${hasScript && hasStyle ? '' : '<div class="plan-skeleton-error">Webview assets missing. Run <code>make vscode-plugin</code> and reload VS Code.</div>'}
    </div>
  </div>
  <script nonce="${nonce}">
    (function() {
      const statusEl = document.getElementById('settings-skeleton-status');
      const initialStatus = statusEl ? statusEl.textContent : '';
      const setStatus = (text) => {
        if (statusEl) statusEl.textContent = text;
      };
      const setStatusIfUnchanged = (text) => {
        if (!statusEl) return;
        if (statusEl.textContent === initialStatus) {
          statusEl.textContent = text;
        }
      };

      window.addEventListener('error', (event) => {
        const message = event && event.message ? event.message : 'Unknown error';
        setStatus('Webview error: ' + message);
      });

      window.addEventListener('unhandledrejection', (event) => {
        let reason = 'Unknown rejection';
        if (event && event.reason) {
          try { reason = String(event.reason); } catch (_) {}
        }
        setStatus('Webview rejection: ' + reason);
      });

      const script = document.createElement('script');
      script.src = "${scriptUri}";
      script.type = "module";
      script.nonce = "${nonce}";
      script.onload = () => {
        setStatusIfUnchanged('Webview script loaded; waiting for init...');
        setTimeout(() => {
          setStatusIfUnchanged('Webview script loaded but did not initialize.');
        }, 2000);
      };
      script.onerror = () => setStatus('Failed to load webview script.');
      document.body.appendChild(script);
    })();
  </script>
</body>
</html>`;
  }

  private getNonce(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let value = '';
    for (let i = 0; i < 32; i += 1) {
      value += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return value;
  }
}
