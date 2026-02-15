(() => {
  const statusEl = document.getElementById('settings-skeleton-status');
  if (statusEl) {
    statusEl.textContent = 'Rendering Settings placeholder...';
  }

  const root = document.getElementById('settings-root');
  if (!root) {
    if (statusEl) {
      statusEl.textContent = 'Missing #settings-root element in webview HTML.';
    }
    return;
  }

  root.innerHTML = `
    <main class="settings-placeholder" role="status" aria-live="polite">
      <div class="settings-placeholder-icon" aria-hidden="true">&#x1F6A7;</div>
      <div class="settings-placeholder-title">Settings</div>
      <div class="settings-placeholder-subtitle">Under Construction</div>
      <p class="settings-placeholder-body">
        Settings controls will live here. Expect configuration, defaults, and
        quality-of-life toggles for Agentize workflows.
      </p>
    </main>
  `;

  if (statusEl) {
    statusEl.textContent = 'Settings placeholder ready.';
  }
})();
