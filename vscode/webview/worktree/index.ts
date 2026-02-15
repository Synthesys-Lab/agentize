(() => {
  const statusEl = document.getElementById('worktree-skeleton-status');
  if (statusEl) {
    statusEl.textContent = 'Rendering Worktree placeholder...';
  }

  const root = document.getElementById('worktree-root');
  if (!root) {
    if (statusEl) {
      statusEl.textContent = 'Missing #worktree-root element in webview HTML.';
    }
    return;
  }

  root.innerHTML = `
    <main class="worktree-placeholder" role="status" aria-live="polite">
      <div class="worktree-placeholder-icon" aria-hidden="true">&#x1F6A7;</div>
      <div class="worktree-placeholder-title">Worktree</div>
      <div class="worktree-placeholder-subtitle">Under Construction</div>
      <p class="worktree-placeholder-body">
        Worktree visibility is on the way. This tab will focus on repository
        context, branches, and activity snapshots.
      </p>
    </main>
  `;

  if (statusEl) {
    statusEl.textContent = 'Worktree placeholder ready.';
  }
})();
