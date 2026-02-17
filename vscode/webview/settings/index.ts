type VsCodeApi = { postMessage(message: unknown): void };

declare function acquireVsCodeApi(): VsCodeApi;

const getVsCodeApi = (): VsCodeApi => {
  const scope = globalThis as typeof globalThis & { __agentizeVsCodeApi__?: VsCodeApi };
  if (scope.__agentizeVsCodeApi__) {
    return scope.__agentizeVsCodeApi__;
  }
  if (typeof acquireVsCodeApi !== 'function') {
    throw new Error('VS Code webview API is unavailable.');
  }
  const api = acquireVsCodeApi();
  scope.__agentizeVsCodeApi__ = api;
  return api;
};

type SettingsLinkConfig = {
  id: string;
  label: string;
  path: string;
};

const settingsLinks: SettingsLinkConfig[] = [
  { id: 'metadata', label: 'Metadata', path: '.agentize.yaml' },
  { id: 'repo-local', label: 'Repo Local', path: '.agentize.local.yaml' },
  { id: 'user-local', label: 'User Local', path: '~/.agentize.local.yaml' },
];

(() => {
  const statusEl = document.getElementById('settings-skeleton-status');
  if (statusEl) {
    statusEl.textContent = 'Initializing Settings UI...';
  }

  let vscode: VsCodeApi;
  try {
    vscode = getVsCodeApi();
  } catch (error) {
    if (statusEl) {
      statusEl.textContent = `Failed to initialize VS Code webview API: ${String(error)}`;
    }
    return;
  }

  const root = document.getElementById('settings-root');
  if (!root) {
    if (statusEl) {
      statusEl.textContent = 'Missing #settings-root element in webview HTML.';
    }
    return;
  }

  root.innerHTML = `
    <main class="settings-shell">
      <header class="settings-header">
        <div class="settings-title">Settings</div>
        <p class="settings-subtitle">
          Open a settings file to edit directly in the VS Code editor.
        </p>
        <div id="settings-status" class="settings-status" role="status" aria-live="polite">Pick a file below.</div>
      </header>
      <section class="settings-links" aria-label="Settings files">
        ${settingsLinks
          .map(
            (item) => `
          <a class="settings-link" href="#" data-settings-link="${item.id}" data-path="${item.path}">
            ${item.label}: <span class="settings-link-path">${item.path}</span>
          </a>`,
          )
          .join('')}
      </section>
    </main>
  `;

  if (statusEl) {
    statusEl.textContent = 'Settings UI ready.';
  }

  const statusLine = document.getElementById('settings-status');

  const postMessage = (message: unknown) => vscode.postMessage(message);

  const setStatusLine = (message: string, tone: 'info' | 'error' = 'info') => {
    if (!statusLine) {
      return;
    }
    statusLine.textContent = message;
    statusLine.classList.toggle('is-error', tone === 'error');
  };

  root.addEventListener('click', (event) => {
    const target = event.target as HTMLElement;
    const link = target.closest<HTMLAnchorElement>('a[data-settings-link]');
    if (!link) {
      return;
    }
    event.preventDefault();
    const filePath = link.dataset.path ?? '';
    if (!filePath) {
      return;
    }
    setStatusLine(`Opening ${filePath} in editor...`, 'info');
    postMessage({
      type: 'link/openFile',
      path: filePath,
      createIfMissing: true,
    });
  });
})();
