declare function acquireVsCodeApi(): { postMessage(message: unknown): void };

type SettingsScope = 'repo' | 'global';

type SettingsSnapshot = {
  path: string;
  exists: boolean;
  content: string;
  backend?: string;
};

type SettingsPayload = {
  agentize: SettingsSnapshot;
  repo: SettingsSnapshot;
  global: SettingsSnapshot;
};

type SettingsMessage =
  | { type: 'settings/loaded'; payload: SettingsPayload }
  | { type: 'settings/saved'; payload: { scope: SettingsScope; settings: SettingsPayload } }
  | { type: 'settings/error'; payload: { message: string; scope?: SettingsScope } }
  | { type?: string; payload?: unknown };

(() => {
  const statusEl = document.getElementById('settings-skeleton-status');
  if (statusEl) {
    statusEl.textContent = 'Initializing Settings UI...';
  }

  let vscode: { postMessage(message: unknown): void } | undefined;
  try {
    vscode = acquireVsCodeApi();
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
          Configure backend defaults for Agentize planning and implementation runs.
          Values are written to local Agentize YAML files.
        </p>
        <div id="settings-status" class="settings-status" role="status" aria-live="polite">Loading settings...</div>
      </header>

      <section class="settings-section" aria-labelledby="settings-meta-title">
        <div class="settings-section-header">
          <div>
            <div id="settings-meta-title" class="settings-section-title">.agentize.yaml</div>
            <div id="agentize-path" class="settings-path"></div>
          </div>
          <span class="settings-tag">Read-only</span>
        </div>
        <pre id="agentize-content" class="settings-code"></pre>
      </section>

      <section class="settings-section" aria-labelledby="settings-repo-title">
        <div class="settings-section-header">
          <div>
            <div id="settings-repo-title" class="settings-section-title">.agentize.local.yaml (repo)</div>
            <div id="repo-path" class="settings-path"></div>
          </div>
          <span class="settings-tag">Editable</span>
        </div>
        <div class="settings-summary">Current backend: <span id="repo-current">Not set</span></div>
        <div class="settings-form">
          <div class="settings-field-grid">
            <div class="settings-field">
              <label class="settings-label" for="repo-provider">Provider</label>
              <select id="repo-provider" class="settings-select"></select>
            </div>
            <div class="settings-field">
              <label class="settings-label" for="repo-model">Model</label>
              <input id="repo-model" class="settings-input" type="text" placeholder="opus, sonnet, gpt-5.2-codex" />
            </div>
          </div>
          <div class="settings-actions">
            <button id="repo-save" class="primary" type="button">Save repo backend</button>
            <span id="repo-status" class="settings-inline-status"></span>
          </div>
          <div class="settings-note">Writes planner.backend in the repo-level config.</div>
        </div>
        <pre id="repo-content" class="settings-code"></pre>
      </section>

      <section class="settings-section" aria-labelledby="settings-global-title">
        <div class="settings-section-header">
          <div>
            <div id="settings-global-title" class="settings-section-title">~/.agentize.local.yaml (global)</div>
            <div id="global-path" class="settings-path"></div>
          </div>
          <span class="settings-tag">Editable</span>
        </div>
        <div class="settings-summary">Current backend: <span id="global-current">Not set</span></div>
        <div class="settings-form">
          <div class="settings-field-grid">
            <div class="settings-field">
              <label class="settings-label" for="global-provider">Provider</label>
              <select id="global-provider" class="settings-select"></select>
            </div>
            <div class="settings-field">
              <label class="settings-label" for="global-model">Model</label>
              <input id="global-model" class="settings-input" type="text" placeholder="opus, sonnet, gpt-5.2-codex" />
            </div>
          </div>
          <div class="settings-actions">
            <button id="global-save" class="primary" type="button">Save global backend</button>
            <span id="global-status" class="settings-inline-status"></span>
          </div>
          <div class="settings-note">Writes planner.backend in the global config.</div>
        </div>
        <pre id="global-content" class="settings-code"></pre>
      </section>
    </main>
  `;

  if (statusEl) {
    statusEl.textContent = 'Settings UI ready.';
  }

  const providers = ['claude', 'openai', 'codex', 'cursor', 'kimi'];

  const statusLine = document.getElementById('settings-status');
  const agentizePath = document.getElementById('agentize-path');
  const agentizeContent = document.getElementById('agentize-content');
  const repoPath = document.getElementById('repo-path');
  const repoContent = document.getElementById('repo-content');
  const repoCurrent = document.getElementById('repo-current');
  const repoStatus = document.getElementById('repo-status');
  const repoSave = document.getElementById('repo-save') as HTMLButtonElement | null;
  const repoProvider = document.getElementById('repo-provider') as HTMLSelectElement | null;
  const repoModel = document.getElementById('repo-model') as HTMLInputElement | null;
  const globalPath = document.getElementById('global-path');
  const globalContent = document.getElementById('global-content');
  const globalCurrent = document.getElementById('global-current');
  const globalStatus = document.getElementById('global-status');
  const globalSave = document.getElementById('global-save') as HTMLButtonElement | null;
  const globalProvider = document.getElementById('global-provider') as HTMLSelectElement | null;
  const globalModel = document.getElementById('global-model') as HTMLInputElement | null;

  const postMessage = (message: unknown) => vscode?.postMessage(message);

  const setStatusLine = (message: string, tone: 'info' | 'error' = 'info') => {
    if (!statusLine) {
      return;
    }
    statusLine.textContent = message;
    statusLine.classList.toggle('is-error', tone === 'error');
  };

  const setInlineStatus = (scope: SettingsScope, message: string, tone: 'info' | 'error' | 'success' = 'info') => {
    const target = scope === 'repo' ? repoStatus : globalStatus;
    if (!target) {
      return;
    }
    target.textContent = message;
    target.classList.toggle('is-error', tone === 'error');
    target.classList.toggle('is-success', tone === 'success');
  };

  const setSaveDisabled = (scope: SettingsScope, disabled: boolean) => {
    const button = scope === 'repo' ? repoSave : globalSave;
    if (button) {
      button.disabled = disabled;
    }
  };

  const ensureProviderOption = (select: HTMLSelectElement, provider: string) => {
    if (!provider) {
      return;
    }
    const exists = Array.from(select.options).some((option) => option.value === provider);
    if (exists) {
      return;
    }
    const option = document.createElement('option');
    option.value = provider;
    option.textContent = `${provider} (custom)`;
    select.appendChild(option);
  };

  const buildProviderSelect = (select: HTMLSelectElement | null) => {
    if (!select) {
      return;
    }
    select.innerHTML = '';
    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = 'Select provider';
    placeholder.disabled = true;
    placeholder.selected = true;
    select.appendChild(placeholder);

    providers.forEach((provider) => {
      const option = document.createElement('option');
      option.value = provider;
      option.textContent = provider;
      select.appendChild(option);
    });
  };

  const stripQuotes = (value: string): string => {
    const trimmed = value.trim();
    if (
      (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
      (trimmed.startsWith("'") && trimmed.endsWith("'"))
    ) {
      return trimmed.slice(1, -1);
    }
    return trimmed;
  };

  const splitBackend = (backend: string): { provider: string; model: string } => {
    const trimmed = stripQuotes(backend);
    const separator = trimmed.indexOf(':');
    if (separator <= 0 || separator >= trimmed.length - 1) {
      return { provider: '', model: '' };
    }
    return {
      provider: trimmed.slice(0, separator),
      model: trimmed.slice(separator + 1),
    };
  };

  const applyBackend = (scope: SettingsScope, backend?: string) => {
    const select = scope === 'repo' ? repoProvider : globalProvider;
    const input = scope === 'repo' ? repoModel : globalModel;
    const current = scope === 'repo' ? repoCurrent : globalCurrent;
    if (!select || !input || !current) {
      return;
    }

    if (!backend) {
      select.value = '';
      input.value = '';
      current.textContent = 'Not set';
      return;
    }

    const { provider, model } = splitBackend(backend);
    if (provider) {
      ensureProviderOption(select, provider);
    }
    select.value = provider || '';
    input.value = model;
    current.textContent = provider && model ? `${provider}:${model}` : 'Not set';
  };

  const applySnapshot = (
    snapshot: SettingsSnapshot,
    pathEl: HTMLElement | null,
    contentEl: HTMLElement | null,
    emptyLabel: string,
  ) => {
    if (pathEl) {
      pathEl.textContent = snapshot.path || emptyLabel;
    }
    if (!contentEl) {
      return;
    }
    const content = snapshot.exists ? snapshot.content.trimEnd() : '';
    if (!content) {
      contentEl.textContent = snapshot.exists ? '(empty file)' : 'File not found.';
      contentEl.classList.add('is-empty');
    } else {
      contentEl.textContent = content;
      contentEl.classList.remove('is-empty');
    }
  };

  const applySettings = (payload: SettingsPayload) => {
    applySnapshot(payload.agentize, agentizePath, agentizeContent, 'Workspace not available');
    applySnapshot(payload.repo, repoPath, repoContent, 'Workspace not available');
    applySnapshot(payload.global, globalPath, globalContent, 'Home directory not available');
    applyBackend('repo', payload.repo.backend);
    applyBackend('global', payload.global.backend);
    setStatusLine('Settings loaded.', 'info');
  };

  const saveScope = (scope: SettingsScope) => {
    const select = scope === 'repo' ? repoProvider : globalProvider;
    const input = scope === 'repo' ? repoModel : globalModel;
    if (!select || !input) {
      return;
    }
    const provider = select.value.trim();
    const model = input.value.trim();
    if (!provider) {
      setInlineStatus(scope, 'Select a provider.', 'error');
      return;
    }
    if (!model) {
      setInlineStatus(scope, 'Enter a model name.', 'error');
      return;
    }
    const backend = `${provider}:${model}`;
    setInlineStatus(scope, 'Saving...', 'info');
    setSaveDisabled(scope, true);
    postMessage({ type: 'settings/save', payload: { scope, backend } });
  };

  buildProviderSelect(repoProvider);
  buildProviderSelect(globalProvider);

  repoSave?.addEventListener('click', () => saveScope('repo'));
  globalSave?.addEventListener('click', () => saveScope('global'));

  window.addEventListener('message', (event: MessageEvent) => {
    const message = event.data as SettingsMessage;
    if (!message || typeof message !== 'object') {
      return;
    }
    switch (message.type) {
      case 'settings/loaded': {
        const payload = message.payload as SettingsPayload;
        applySettings(payload);
        return;
      }
      case 'settings/saved': {
        const payload = message.payload as { scope: SettingsScope; settings: SettingsPayload };
        const scope = payload.scope;
        applySettings(payload.settings);
        setInlineStatus(scope, 'Saved.', 'success');
        setSaveDisabled(scope, false);
        return;
      }
      case 'settings/error': {
        const payload = message.payload as { message: string; scope?: SettingsScope };
        const scope = payload.scope;
        setStatusLine(payload.message, 'error');
        if (scope) {
          setInlineStatus(scope, payload.message, 'error');
          setSaveDisabled(scope, false);
        }
        return;
      }
      default:
        return;
    }
  });

  postMessage({ type: 'settings/load' });
})();
